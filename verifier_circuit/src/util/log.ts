import { ForeignFieldBn254, Provable, ProvableBn254 } from "o1js";

export function logField<T extends ForeignFieldBn254>(message: string, element: T) {
    ProvableBn254.asProver(() => console.log(message, element.toBigInt()));
}
