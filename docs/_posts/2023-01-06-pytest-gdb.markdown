---
layout: post
title:  "On writing unit tests for embedded software in Python"
date:   2023-01-06 21:40:01 +0100
categories: tutorial gdb pytest
description: A technique to easily write unit tests in Python, including pytest and its plugins, and have these tests run directly our embedded code, written in C, thanks to the gdb debugger..
comment_issue_id: 4
---

# Using Pytest framework and gdb to easily write unit tests for embedded software

Testing... Is it just a necessary evil? I don't know if that's only in my experience, but in the 10 years I have been designing embedded software as a professional, I've always heard people say that testing is essential and yet rarely see a thorough test framework for unit and integration tests. Validation tests, where the product is seen as a "black box", are usually the only form of testing that the project really delivers, sometimes through another, dedicated, team.

My view is that unit testing (and in a lesser extend, integration testing) is essential indeed, and there is a simple point that we always use in my team when in need to convince a newcomer: as a developper, we always test the code we write. It's just that usually:
1. we include some temporary hacks in our code: printf, manual execution of the debuggers, specially-crafted environments...
1. we don't test extensively, just a few use cases
1. we throw away the tests once the feature is implemented

When working on embedded systems, testing is even a bit harder. Unit testing can (and should, in my opinion) be done on the host (or maybe ideally, in a virtual environment that simulates the target) but there is always the risk (altough limited if analysed) to miss some issues due to host and target architecture being different (endianess, width of the `int` type).

**So, the solution to this would be: we need to have a framework that makes writing tests so easy, simple and straightforward, that developpers will actually *enjoy* writing tests (TDD, here we come!).**

When you think about it, writing unit tests is actually tedious: many frameworks are there to help us with the common work (set-up/tear-down, grouping tests, etc...) but eventually, writing a test in C is as limited as C itself. On the other hand, when developping in Python, I am always amazed at how easy it is to write unit tests, because the Python language is so flexible it fits perfectly for that purpose.

What if we could write tests in Python for our C functions? Furthermore, what if we could run the tests on the target directly, and easily? **It is actually suprisingly easy to do so, thanks to gdb, the GNU debugger, as it supports extensions written in Python!**

> FIXME: I believe it would be even easier using lldb which has been designed from start to be scriptable in Python. By the time of writing this note, my knowledge of lldb is too scarce to write something about it but it is definitely something I want to look at some point.

This note details the procedure to set up the environment and start writing unit tests for embedded software, in python, thus leveraging the powerful Python test frameworks (like pytest) directly in the target environment, with practically no intermediary steps.

## Basic idea

I am unsure of when gdb has started supporting Python extensions, but it's been at least a few years. The interface documentation is available on the [official gdb doc](https://sourceware.org/gdb/onlinedocs/gdb/Python-API.html).

The most common usages of this API we usually see on the web (and these are really useful!) are pretty-printers written in Python. I am a personal fan of the [gdb dashboard](https://github.com/cyrus-and/gdb-dashboard) and it is now the only interface I need when using gdb.

The other important feature of gdb for our current problem is gdb's [call](https://sourceware.org/gdb/onlinedocs/gdb/Calling.html#Calling) function, that let's you call an arbitrary C function on the debugged target from gdb interpreter, and get the return value (this works particularly well for stateless functions, and has limitations when the function has side effects because, after-all, you're still using a debugger). This command was a real game-changer for me. Using it makes you feel like you are in an interpreted language, it is really powerful.

**So, the basic idea is to develop test scripts in Python, that will make use of gdb's *call* command, and to tell gdb to execute the test script.**

And that's it. It's suprisingly easy.

### In practice

Let's work on a real-life example: an integer range conversion function with rounding (ie: map from one scale to another).

We will need the following tools for this experiment:
* gcc and gdb for your target architecture. In my case, I am using gdb-multiarch 9.2; I think Python 3 has been supported by gdb since version 8? I'm not sure about it.
* Python: I think the interpreter is included in the gdb release. 
  * *FIXME: check if this is true*
* your target device. In my case, a Silicon labs EFR32MG12 on a [Thunderboard](https://www.silabs.com/development-tools/thunderboard/thunderboard-bg22-kit?tab=overview)
* JTAG interface to your target device with a gdb server running on the host. In my case, I use the Thunderboard's onboard J-Link debugger and [JLinkGDBServer](https://www.segger.com/products/debug-probes/j-link/tools/j-link-gdb-server/about-j-link-gdb-server/)

#### Software to test
On the software side, we will use a minimal program that you can find on [my github repo](https://github.com/EmmanuelPauchard/gdb-tests). Basically, it goes like this:
```c
#include <stdio.h>
#include <stdint.h>

// gcc 'used' and 'noinline' attribute makes sure the symbol is not optimized away
/**
 * Divide a by div, rounding to the nearest integer
 */
__attribute__((used, noinline)) uint32_t divide_and_round_to_nearest_int(uint32_t a, uint32_t div) {
  return (a + div/2) / div;
}

int main(int argc, char* argv[]) {
	printf("Hello, world");
}
```

The implementation of `divide_and_round_to_nearest_integer_int` will obviously overflow in `a + div/2`, but this is a simple example. We will create a unit test that will try to check this.

#### Test scripts
We will now write our test script in Python. In this example, I will even use pytest, although this is purely optional. But I do love using pytest and `parametrize`.

So, first create a test script, in our case I will simply redefine a reference implementation in Python and we will compare the output of both functions:
```python
import pytest
import decimal
decimal.getcontext().rounding = decimal.ROUND_HALF_UP


def divide_and_round_to_nearest_int(number, div):
    """Reference implementation of the tested function
    """
    return int((decimal.Decimal(number) / decimal.Decimal(div)).to_integral())


@pytest.mark.parametrize(
    "input, expected_value",
    [(a, divide_and_round_to_nearest_int(a, 10)) for a in range(2**8)],
)
def test_divide_and_round(gdb_setup, input, expected_value):
    """Unit-test: divide_and_round_to_nearest_int. Call it on the whole
    range and compare with a reference python implementation.
	:note: we limit our test to value 10 for the divisor
    """
    result = gdb.parse_and_eval("divide_and_round_to_nearest_int({}, 10)".format(input))
    assert int(result) == expected_value

```

This part of the code hides all complexity related to gdb. Instead, the test function references a fixture `gdb_setup` which needs to be implemented as described in the next section.

#### Test environment and gdb-python glue

The test depends on a fixture, that will put the target in a controlled state: in my case, I've chosen to break at `main`.

This may not be necessary but can sometimes be useful, for instance when your device implements low-power modes and the code you are testing interacts with some peripherals (although there are [limitations](#Limitations)). In my tests I observed, but did not prove, that resetting and breaking at main improved the reliability of the technique.

```python
import pytest
import gdb

@pytest.fixture(scope="session")
def gdb_setup():
    gdb.Breakpoint("main")
    gdb.execute("target remote localhost:2331")
    gdb.execute("monitor reset")
    gdb.execute("continue")
```

Finally, the last part is to create the link between gdb and Python. Unlike lldb, it is not possible to call gdb from Python (which would have been ideal, hence the necessity to evaluate switching to lldb).
Instead, we must start gdb and source the Python script. We will use an intermediate script to start pytest as follows:

```python
import pytest
import gdb


pytest.main(["--noconftest", "test_conversion.py", "--html=out.html"])
gdb.execute("quit")
```

As you can see, this example even produces an HTML test report using [pytest-html](https://pypi.org/project/pytest-html/).

#### Executing the tests
Simply launch gdb with the `-x` argument to indicate it must source a Python script. `-q` is used to enable quiet mode and remove intro and copyright.

```shell
$ gdb-multiarch -q ./empty.axf -x launch_test.py 
Reading symbols from ./empty.axf...
============================= test session starts ==============================
platform linux -- Python 3.8.10, pytest-6.2.5, py-1.10.0, pluggy-1.0.0
rootdir: /home/epauchard/projects/perso/gdb-tests
plugins: allure-pytest-2.9.43, html-3.1.1, metadata-1.11.0
collected 259 items

test_conversion.py ..................................................... [ 20%]
........................................................................ [ 48%]
........................................................................ [ 76%]
...........................................................FFF           [100%]

=================================== FAILURES ===================================
_________________ test_divide_and_round[4294967295-429496730] __________________

gdb_setup = None, input = 4294967295, expected_value = 429496730

    @pytest.mark.parametrize(
        "input, expected_value",
        [(a, divide_and_round_to_nearest_int(a, 10)) for a in range(2**8)] +
        [(2**32-1, divide_and_round_to_nearest_int(2**32-1, 10))] +
        [(2**32-5, divide_and_round_to_nearest_int(2**32-5, 10))] +
        [(2**32-10, divide_and_round_to_nearest_int(2**32-10, 10))]
    )
    def test_divide_and_round(gdb_setup, input, expected_value):
        """Unit-test: divide_and_round_to_nearest_int. Call it on the whole
        range and compare with a reference python implementation.
        """
        result = gdb.parse_and_eval("divide_and_round_to_nearest_int({}, 10)".format(input))
>       assert int(result) == expected_value
E       assert 0 == 429496730
E        +  where 0 = int(<gdb.Value object at 0x7f5f04b8ecf0>)

test_conversion.py:40: AssertionError
_________________ test_divide_and_round[4294967291-429496729] __________________

gdb_setup = None, input = 4294967291, expected_value = 429496729

    @pytest.mark.parametrize(
        "input, expected_value",
        [(a, divide_and_round_to_nearest_int(a, 10)) for a in range(2**8)] +
        [(2**32-1, divide_and_round_to_nearest_int(2**32-1, 10))] +
        [(2**32-5, divide_and_round_to_nearest_int(2**32-5, 10))] +
        [(2**32-10, divide_and_round_to_nearest_int(2**32-10, 10))]
    )
    def test_divide_and_round(gdb_setup, input, expected_value):
        """Unit-test: divide_and_round_to_nearest_int. Call it on the whole
        range and compare with a reference python implementation.
        """
        result = gdb.parse_and_eval("divide_and_round_to_nearest_int({}, 10)".format(input))
>       assert int(result) == expected_value
E       assert 0 == 429496729
E        +  where 0 = int(<gdb.Value object at 0x7f5f04b8e8b0>)

test_conversion.py:40: AssertionError
_________________ test_divide_and_round[4294967286-429496729] __________________

gdb_setup = None, input = 4294967286, expected_value = 429496729

    @pytest.mark.parametrize(
        "input, expected_value",
        [(a, divide_and_round_to_nearest_int(a, 10)) for a in range(2**8)] +
        [(2**32-1, divide_and_round_to_nearest_int(2**32-1, 10))] +
        [(2**32-5, divide_and_round_to_nearest_int(2**32-5, 10))] +
        [(2**32-10, divide_and_round_to_nearest_int(2**32-10, 10))]
    )
    def test_divide_and_round(gdb_setup, input, expected_value):
        """Unit-test: divide_and_round_to_nearest_int. Call it on the whole
        range and compare with a reference python implementation.
        """
        result = gdb.parse_and_eval("divide_and_round_to_nearest_int({}, 10)".format(input))
>       assert int(result) == expected_value
E       assert 0 == 429496729
E        +  where 0 = int(<gdb.Value object at 0x7f5f04bb9970>)

test_conversion.py:40: AssertionError
- generated html file: file:///home/epauchard/projects/perso/gdb-tests/out.html -
=========================== short test summary info ============================
FAILED test_conversion.py::test_divide_and_round[4294967295-429496730] - asse...
FAILED test_conversion.py::test_divide_and_round[4294967291-429496729] - asse...
FAILED test_conversion.py::test_divide_and_round[4294967286-429496729] - asse...
======================== 3 failed, 256 passed in 15.90s ========================
A debugging session is active.

	Inferior 1 [Remote target] will be killed.

Quit anyway? (y or n) [answered Y; input not from terminal]
```

That's it! We've successfully written our unit test in Python, and we even got the test result with pytest-html (also works with pytest-allure). The test showed us that our implementation indeed overflowed and thus produced incorrect result for values higher than `2**32 - div/2`.

## Conclusion

### Benefits of the solution
* Use Python to write test scripts and thus:
  * writing tests is easy as you benefit from a flexible language
  * [if applicable] reuse the same test framework (pytest, reports format) as the one you already use for validation tests - less maintenance, only one framework to learn
* No need for a specific, modified software for tests (ie: `#ifdef TESTS`)
  * Except if the compiler is inlining the tested functions in which case you do need to deactivate, altough temporarily, optimizations. This is ideally done globally as a make target but defeats a bit the purpose;
* The solution can be extended, in some cases and with some limitations, to some software/hardware integration tests: at least, for simple designs (direct write in peripherals, no interrupt involved) it should work. Keep in mind that the core is halted by the debugger during these tests, but the periopherals could still be operational depending on your configuration.
  
### Limitations
* Nothing that can't be done in embedded C: it's just less convenient
* Tests run relatively slowly. This could be a problem when multiplying the number of tests, which is precisely the purpose we have here!
* Depending on your gdb-server, you may experience some instability (in my case, sometimes the server crashes) which would really be problematic in an all integrated automatic test framework where each component needs to be reliable
* If the tested function has side effect, you may or may not manage to test it. It depends on the side effect and what is available while the core is halted by the debugger (for instances, some peripheral may still be available, but interrupts will not be served).
* Because this test method induces a latency (debugger, breakpoint catch + python interpreter), you can't reliably test time-sensitive functions. For instance, trying to debug during a Bluetooth connection will break the connection.

## Further work
The Holy Grail for me would be to define a way to perform integration tests. In my opinion, these tests are really the most difficult to implement because you need to stub or mock the dependencies. 

The idea here would be to use GDB and Python to implement the mocks, as follows:
* Set up a breakpoint in all dependencies that you want to mock
* Set up, in Python, the breakpoint handler `gdb.events.stop.connect(stop_handler)`
* In the breakpoint handler, use gdb to directly fill the return variable and force function return, thus skipping the actual implementation of the function
* Call the tested function and let gdb + Python do the rest

Unfortunately, this does not work, at least in my gdb version (GNU gdb (Ubuntu 9.2-0ubuntu1~20.04.1) 9.2) when reaching a breakpoint in a function that you `call`, you get the following error message:

```
The program being debugged stopped while in a function called from GDB.
Evaluation of the expression containing the function
(divide_and_round_to_nearest_int) will be abandoned.
When the function is done executing, GDB will silently stop.
```

I have not gone further this way. My next actions would be:
- try again with latest gdb
- try with lldb


## Conclusion

Overall, I must admit that I never put that idea into production in one of my projects, wether at home or at work. But I found the power of gdb's `call` so exciting that I thought it was worth sharing! And, by the way, I use this function on gdb's command line all the time, it's really powerful!

What about you? Is that a feature that you already knew, is it more common than what I realized? What is your solution to ensure writing tests is easy?
