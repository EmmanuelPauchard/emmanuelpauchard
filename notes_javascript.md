# Javascript Tutorial

Despite the name, this is not a Javascript Tutorial. The following are just notes and references to existing tutorials.

# References
## [Airbnb Coding style](https://github.com/airbnb/javascript)
## [MDN Intermediate Tutorial](https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Objects)

# Javascript Objects
## Intro
> "In JavaScript, we can and often do create objects without any separate class definition, either using a function or an object literal."


https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Objects/

## Object Literal (declaration and definition at the same time)
```js
const person = {
  name: {
    first: "Bob",
    last: "Smith",
  },
  age: 42,
  bio() {
    console.log(`${this.name[0]} ${this.name[1]} is ${this.age} years old.`);
  },
  introduceSelf() {
    console.log(`Hi! I'm ${this.name[0]}.`);
  },
};
```


* To access data in an object:
  * dot notation:
```js
person.age;
person.name.first;
```

  * Bracket notation
```js
person["age"];
person["name"]["first"];
```

> "objects are sometimes called associative arrays — they map strings to values in the same way that arrays map numbers to values."


* Creating properties
One can directly write to a non existing member to create it:
```js
person["eyes"] = "hazel";
person.farewell = function () {
  console.log("Bye everybody!");
};
```

> Use bracket notation if member name comes from a variable

## Constructor
A constructor is a function called with new:
  * When called with new, the function can reference 'this'.
  * When called without new, 'this' is undefined (TBC)

> Note: this seems historical as stated in MDN: "Prior to ES6, which introduced classes, most JavaScript built-ins are both callable and constructible, although many of them exhibit different behaviors. To name a few: Array(), Error(), Date()..."


```js
function Car(make, model, year) {
  this.make = make;
  this.model = model;
  this.year = year;
}

const car1 = new Car('Eagle', 'Talon TSi', 1993);
```

## Classes
```js
class Person {

  name;

  constructor(name) {
    this.name = name;
  }

  introduceSelf() {
    console.log(`Hi! I'm ${this.name}`);
  }

}
```

* Default constructor can be provided
* Declaration of public class properties is optional

## Inheritance and Encaspulation

* Inheritance: keyword "extends". relies on the prototype chain.
* Private data properties must be declared in the class declaration, and their names start with #.

Example:
```js
class Student extends Person {

  #year;

  constructor(name, year) {
    super(name);
    this.#year = year;
  }


  introduceSelf() {
    console.log(`Hi! I'm ${this.name}, and I'm in year ${this.#year}.`);
  }

  canStudyArchery() {
    return this.#year > 1;
  }

  #somePrivateMethod() {
    console.log('You called me?');
  }

}
```

# Notes
* object spread operator: `...`:
    * similar to python's list unpack to function arguments
    * used in JS to make object copy explicit:
    ```js
    const original = { a: 1, b: 2 };
    const copy = { ...original, c: 3 }; // copy => { a: 1, b: 2, c: 3 }
    ```

* object destructuring
```js
// bad
function getFullName(user) {
  const firstName = user.firstName;
  const lastName = user.lastName;

  return `${firstName} ${lastName}`;
}

// good
function getFullName(user) {
  const { firstName, lastName } = user;
  return `${firstName} ${lastName}`;
}

// best
function getFullName({ firstName, lastName }) {
  return `${firstName} ${lastName}`;
}

// on arrays
const [first, second] = arr;
```

* Returning objects instead of arrays
```js
// bad
function processInput(input) {
  // then a miracle occurs
  return [left, right, top, bottom];
}

// the caller needs to think about the order of return data
const [left, __, top] = processInput(input);

// good
function processInput(input) {
  // then a miracle occurs
  return { left, right, top, bottom };
}

// the caller selects only the data they need
const { left, top } = processInput(input);
```

* Template strings: use backtick instead of single tick:
```js
// good
function sayHi(name) {
  return `How are you, ${name}?`;
}
```

* variables use global scope unless explicitly declared local
> Yes, JS took the opposite decision to Python; instead of assuming variables are local, and having to explicitly declare global variables, JS assumes all variables are global unless you explicitly declare them local.
https://www.wooji-juice.com/blog/javascript-article.html

* comparison: === or == (!== or !=)
  * === will not coerce types, and thus, `"2" !== 2`
  * == will coerce types, and thus, `"2" == 2`

* Classes

> [In JavaScript, class methods are not bound by default.If you forget to bind this.handleClick and pass it to onClick, this will be undefined when the function is actually called.](https://reactjs.org/docs/handling-events.html)

# React

# Components

## Important concepts
> Note: [Always start component names with a capital letter.](https://reactjs.org/docs/components-and-props.html)

> [All React components must act like pure functions with respect to their props.](https://reactjs.org/docs/components-and-props.html)

> [The only place where you can assign this.state is the constructor.](https://reactjs.org/docs/components-and-props.html)
  > [setState() automatically merges a partial state into the current state](https://reactjs.org/docs/state-and-lifecycle.html#state-updates-are-merged)

### Props vs State
> [props are a way of passing data from parent to child. If you’re familiar with the concept of state, don’t use state at all to build this static version. State is reserved only for interactivity, that is, data that changes over time. Since this is a static version of the app, you don’t need it.](https://reactjs.org/docs/thinking-in-react.html)

## Notes

* Controlled Component = maintain no state -> use Function Components
  * The controlled component must have "onChange" and "value" attributes
  * The application will use "value" attribute to set the displayed value of the controlled component to the latest value.
  * The application will use "onChange" attribute to keep in its state the input's latest value
  * example:
  ```html
  <input placeholder="Search..." type="search" value={this.props.search} onChange={this.handleSearch}/>
  ```

* Better to use immutable data structures (and full updates) so that React knows when to re-render (reference has changed): https://reactjs.org/docs/optimizing-performance.html#examples

> Note: remember variables store reference to arrays; let a = b; will create a new reference to the same array, data is not duplicated