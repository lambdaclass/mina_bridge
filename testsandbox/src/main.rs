use js_sandbox::Script; //AnyError
use serde::Serialize;

#[derive(Serialize, PartialEq)]
struct Person {
    name: String,
    age: u8,
}

fn main() {
    let src = r#"
    function toString(person) {
        return "A person named " + person.name + " is " + person.age + " years old.";
    }"#;

    let mut script = Script::from_string(src).expect("Initialization succeeds");

    let person = Person {
        name: "Roger".to_string(),
        age: 42,
    };

    let tup = (person,);
    let result: String = script.call("toString", tup).unwrap();
    println!("{result}");
}
