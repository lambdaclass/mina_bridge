import { writeFileSync } from "fs";

export { }

let response = await fetch('http://5.9.57.89:3085/graphql', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    },
    body: '{"query": "{\n  bestChain(maxLength: 1) {\n                protocolStateProof {\n      base64\n    }\n  }\n}"}'
});
const { data } = await response.json();

let encodedProof = data.bestChain[0].protocolStateProof.base64;
console.log(Buffer.from(encodedProof, 'base64'));

// TODO: this should be a JSON formatted proof (using `proof.toJSON(...)`)
writeFileSync("../verifier_circuit/src/proof.txt", encodedProof);
