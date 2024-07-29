# mina_bridge 🌉

## Zero-knowledge state bridge from Mina to Ethereum

## About

This project introduces the proof generation, posting and verification of the validity of [Mina](https://minaprotocol.com/) states into a EVM chain, which will serve as a foundation for token bridging.

This project is being redesigned to use [Aligned Layer](https://github.com/yetanotherco/aligned_layer) to verify Mina proofs on Ethereum.

## Usage

1. [Setup Aligned Devnet locally](https://github.com/yetanotherco/aligned_layer/blob/main/docs/guides/3_setup_aligned.md#booting-devnet-with-default-configs)
1. Setup the `core/.env` file of the bridge's core program. A template is available in `core/.env.template`.
1. In Mina Bridge root run:
```sh
make
```

# Specification

## Architecture
### Core

 [`mina_bridge repo: core/`](https://github.com/lambdaclass/mina_bridge/blob/c13a6e74e2e7231c3ca44de621425286642ca14e/core)


A Rust library+binary project that includes the next modules:

### Mina Polling Service

[`mina_bridge repo: core/mina_polling_service.rs`](https://github.com/lambdaclass/mina_bridge/blob/c13a6e74e2e7231c3ca44de621425286642ca14e/core/src/mina_polling_service.rs)

This module queries a Mina node for the latest state data and proof. 

 - Serializes the constant values.
 These are temporary, we will fetch the tip from the Mina contract instead of using these hardcoded values.  

 - Queries the provided RPC_URL to get the latest block.
 - Serializes the protocol state and the proof of the latest block.
    - serialize_protocol_state_proof extracts and serializes the proof of the latest block from the provided JSON response.
    - get_protocol_state extracts and serializes the protocol state of the latest block from the provided JSON response  

    In detail, it serializes:  
    - the state (an OCaml structure encoded in base64, standard vocabulary) as bytes, representing the underlying UTF-8.
    - the state hash (field element) as bytes (arkworks serialization).
    - the state proof (an OCaml structure encoded in base64, URL vocabulary) as bytes, representing the underlying UTF-8.

    The first two compose the public inputs and the last one the proof of what we call a [**Mina proof**]. So we end up with two byte arrays (public inputs and proof) in a friendly format for an Aligned operator.  




 - Writes this data to local files.
 - Returns a VerificationData object with the necessary data.
 ```rust
    Ok(VerificationData {
    proving_system: ProvingSystemId::Mina,
    proof,
    pub_input,
    verification_key: None,
    vm_program_code: None,
    proof_generator_addr,
}
```




### Aligned Polling Service

[`mina_bridge repo: core/aligned_polling_service.rs`](https://github.com/lambdaclass/mina_bridge/blob/c13a6e74e2e7231c3ca44de621425286642ca14e/core/src/aligned_polling_service.rs)

This module sends the public input and proof arrays (serialized with the Mina Polling Service) to the Aligned batcher for verification, using the Aligned SDK. Currently it waits until the batch that includes the proof is verified, polling Aligned every 10 seconds (this is done by the Aligned SDK).

Finally the service returns the verification data sent by Aligned after proof submission. This is used for updating the bridge’s smart contract that stores the last verified state hash.

### Smart Contract Utility

[`mina_bridge repo: core/smart_contract_utility.rs`]()

This module calls the bridge’s smart contract `updateLastVerifiedStateHash()` function by sending the verification data retrieved by the Aligned Polling Service. It also exposes an API for getting info from the contract.

### Smart Contract

`mina_bridge repo: contract/`

The contract serves as a cache for storing verified Mina state information. It contains a `updateLastVerifiedStateHash()` function which takes verification data as a parameter, and calls the Aligned Service Manager contract to check that a state proof was indeed verified to then store that state’s info.

A consumer can retrieve info of the last verified state from the contract.

### Aligned’s Mina state verifier

`aligned_layer repo: operator/mina/`

Aligned integrated a Mina verifier in its operator code for verifying Mina state proofs.

### Mina proof

We understand a “Mina proof” to be composed of:

- public inputs: `[candidate_state_hash, candidate_state, last_verified_state_hash, last_verified_state]`
- proof: Kimchi proof of the candidate state (specifically a Wrap proof in the context of the Pickles recursive system). We like to call it “Pickles proof” for simplicity.

#### Consensus checking

The first step of the Mina verifier is to execute consensus checks, specific to the Ouroboros Samasika consensus mechanism that the Mina Protocol uses.

#### State hash check

We check that the candidate state hash is indeed the hash of the candidate state, and the same is done for the last verified state. We include the hash in the public inputs because then the smart contract can call Aligned’s contract to check that a state with a specific hash was verified, and then store that hash.

#### Pickles verification

We are leveraging OpenMina’s “block verifier” to verify the Pickles proof of the candidate state. The verifier takes as public input the hash of the state, and its proof. This is the final step of the Mina state verifier. Audit OpenMina’s verifier code is needed.

## Kimchi proving system

Kimchi is a zero-knowledge proof system that’s a variant of PLONK.

Kimchi represents a series of enhancements, optimizations, and modifications implemented atop PLONK. To illustrate, it addresses PLONK's trusted setup constraint by incorporating a polynomial commitment in a bulletproof-style within the protocol. In this manner, there's no necessity to rely on the honesty of the participants in the trusted setup.

Kimchi increases PLONK's register count from 3 to 15 by adding 12 registers.
With an increased number of registers, Kimchi incorporate gates that accept multiple inputs, as opposed to just two. This unveils new opportunities; for instance, a scalar multiplication gate would necessitate a minimum of three inputs—a scalar and two coordinates for the curve point.

New proof systems resembling PLONK employ custom gates to efficiently represent frequently used functionalities, as opposed to connecting a series of generic gates. Kimchi is among these innovative protocols.

In Kimchi, there's a concept where a gate has the ability to directly record its output onto the registers utilized by the subsequent gate.

Another enhancement in Kimchi involves the incorporation of lookups for performance improvement. Occasionally, certain operations can be expressed in a tabular form, such as an XOR table.

In the beginning, Kimchi relies on an interactive protocol, which undergoes a conversion into a non-interactive form through the Fiat-Shamir transform.

### Proof Construction & Verification

#### Secuence diagram linked to ``proof-systems/kimchi/src/verifier.rs``

![Commitments to secret polynomials](/img/commitments_to_secret_poly.png)

Links to the associated code.

[public input & witness commitment](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L134)

[beta](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L196)

[gamma](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L199)

[permutation commitment](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L206)

---

![Commitments to quotient polynomials](/img/commitments_to_quotient_poly.png)

Links to the associated code.

[alpha](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L213)

[quotient commitment](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L221)

---

![Verifier produces an evaluation point](/img/verifier_produces_evaluation_point.png)

Links to the associated code.

[zeta](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L227)

[change of sponge](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L234)

[recursion challenges](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L236)

---

![Prover provides needed evaluations for the linearization - 1](/img/prover_provides_evaluations_linearization_01.png)

Links to the associated code.

[zeta](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L227)

[negated public input](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L290)

[15 register/witness - 6 sigmas evaluations](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L323)

---

![Prover provides needed evaluations for the linearization - 2](/img/prover_provides_evaluations_linearization_02.png)

Links to the associated code.

TODO

---

![Batch verification of evaluation proofs](/img/batch_verification_evaluation_proofs.png)

Links to the associated code.

[v,u](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L334)

[polynomials that have an evaluation proof](https://github.com/o1-labs/proof-systems/blob/17041948eb2742244464d6749560a304213f4198/kimchi/src/verifier.rs#L346)

## Pickles - Mina’s inductive zk-SNARK composition system

Pickles uses a pair of amicable curves called [Pasta](https://o1-labs.github.io/proof-systems/specs/pasta.html) in order to deliver incremental verifiable computation efficiently.

The two curves pallas and vesta (pa(llas ve)sta) created by the [Zcash team](https://github.com/zcash/pasta?tab=readme-ov-file#pallasvesta-supporting-evidence). Each curve’s scalar field is the other curve’s base field, which is practical for recursion

These curves are referred to as “tick” and “tock” within the Mina source code.

- Tick - Vesta (a.k.a. Step), constraint domain size 2¹⁸  [block and transaction proofs]
- Tock - Pallas (a.k.a. Wrap), constraint domain size 2¹²  [signatures]

The Tock prover does less (only performs recursive verifications and
no other logic), so it requires fewer constraints and has a smaller
domain size.  Internally Pickles refers to Tick and Tock as _Step_ and
_Wrap_, respectively.

One curve handles the current proof, while the other is used to verify previous proofs.

Tock is used to prove the verification of a Tick proof and outputs a
Tick proof.  Tick is used to prove the verification of a Tock proof and
outputs a Tock proof.  In other words,

- Prove_tock ( Verify(_Tick_) ) = Tick_proof

- Prove_tick (Verify(_Tock_) ) = Tock_proof

![Description](/img/palas_vesta.png)

Both Tick and Tock can verify at most 2 proofs of the opposite kind, though, theoretically more is possible.

Currently, in Mina we have the following situation.

- Every Tock always wraps 1 Tick proof.  
- Tick proofs can verify 2 Tock proofs
  - Blockchain SNARK takes previous blockchain SNARK proof and a transaction proof
  - Verifying two Tock transaction proofs

Pickles works over [Pasta](https://o1-labs.github.io/proof-systems/specs/pasta.html), a cycle of curves consisting of Pallas and Vesta, and thus it defines two generic circuits, one for each curve. Each can be thought of as a parallel instantiation of a kimchi proof systems. These circuits are not symmetric and have somewhat different function:

- **Step circuit**: this is the main circuit that contains application logic. Each step circuit verifies a statement and potentially several (at most 2) other wrap proofs.
- **Wrap circuit**: this circuit merely verifies the step circuit, and does not have its own application logic. The intuition is that every time an application statement is proven it’s done in Step, and then the resulting proof is immediately wrapped using Wrap.

---

Both [Step and Wrap circuits](https://o1-labs.github.io/proof-systems/pickles/overview.html#general-circuit-structure) additionally do a lot of recursive verification of the previous steps. Without getting too technical, Step (without loss of generality) does the following:

1. Execute the application logic statement (e.g. the mina transaction is valid)
2. Verify that the previous Wrap proof is (first-)half-valid (perform only main checks that are efficient for the curve)
3. Verify that the previous Step proof is (second-)half-valid (perform the secondary checks that were inefficient to perform when the previous Step was Wrapped)
4. Verify that the previous Step correctly aggregated the previous accumulator, e.g. acc2=Aggregate(acc1,_π_ step,2)

![Step-Wrap Diagram](/img/step_diagram.png)

---

### Accumulator

The accumulator is an abstraction introduced for the purpose of this diagram. In practice, each kimchi proof consists of (1) commitments to polynomials, (2) evaluations of them, (3) and the opening proof.

What we refer to as **accumulator** here is actually the commitment inside the opening proof. It is called `sg` in the implementation and is semantically a polynomial commitment to `h(X)` (`b_poly` in the code) — the poly-sized polynomial that is built from IPA challenges.

It’s a very important polynomial – it can be evaluated in log time, but the commitment verification takes poly time, so the fact that `sg` is a commitment to `h(X)` is never proven inside the circuit. For more details, see [Proof-Carrying Data from Accumulation Schemes](https://eprint.iacr.org/2020/499.pdf), Appendix A.2, where `sg` is called `U`.

In pickles, what we do is that we “absorb” this commitment `sg` from the previous step while creating a new proof.

That is, for example, Step 1 will produce this commitment that is denoted as `acc1` on the diagram, as part of its opening proof, and Step 2 will absorb this commitment. And this “absorbtion” is what Wrap 2 will prove (and, partially, Step 3 will also refer to the challenges used to build `acc1`, but this detail is completely avoided in this overview). In the end, `acc2` will be the result of Step 2, so in a way `acc2` “aggregates” `acc1` which somewhat justifies the language used.

### Analysis of the Induction (recursion) method applied in Pickles

The **Verifier** is divided into 2 modules, one part **Slow** and one part **Fast**.

![Figure 1](/img/pickles_step_01.png)

**S0** is the initial statement, **U** is the Update algorithm, the **Pi** are the proofs, and the **S's** are the updated statements.

![Figure 2](/img/pickles_step_02.png)

On top of each **Pi** proof, we run a **Fast** verifier. With the **Pi** proof and the cumulative Statement from the previous step, the **U** algorithm is applied and a new updated Statement is created. This _new updated Statement_ is the input of the Slow part of the Verifier, but we don't run the Slow Verifier until we reach the end of the whole round.

---
Execution of **Verifier Slow** (which is very slow) can be **deferred** in sequences, and the V slow current always accumulates to the previous statement. This implicitly 'runs Vs on S1' as well.

---

Remember that the S's are statements that accumulate, so each one has information from the previous ones.

![Figure 3](/img/pickles_step_03.png)

When we reached the last round we see that the intermediate Verifiers Slow disappears, as they are no longer useful to us.

![Figure 4](/img/pickles_step_04.png)

Attention!! We haven't executed any Verifier Slow yet; we only run Verifier Fast in each round.

Therefore, in the last step, we execute the current **Verifier Fast** on its Pi, and the **Last Verifier Slow** on the **Final S**. This may take 1 second, but it accumulates all the previous ones.

![Figure 5](/img/pickles_step_05.png)

---

Everything inside the large red square in the following figure has already been processed by the time we reach the last round.

![Figure 6](/img/pickles_step_06.png)

---

Let's now see how the Verifier Fast is divided.

![Figure 7](/img/pickles_step_07.png)

**Vf** corresponds to field operations in a field **F**, and **Vg** corresponds to group operations in a group **G**.

![Figure 8](/img/pickles_step_08.png)

The proof **Pi** is divided into 2 parts, one corresponding to group operations **G**, and it exposes, as a public input to the circuit, the part of the proof that is necessary to execute **Vf**.

### Pickles Technical Diagrams

  The black boxes are data structures that have names and labels following the implementation.  
  `MFNStep/MFNWrap` is an abbreviation from `MessagesForNextStep` and `MessagesForNextWrap` that is used for brevity. Most other datatypes are exactly the same as in the codebase.  

  The blue boxes are computations. Sometimes, when the computation is trivial or only vaguely indicated, it is denoted as a text sign directly on an arrow.

  Arrows are blue by default and denote moving a piece of data from one place to another with no (or very little) change. Light blue arrows are denoting witness query that is implemented through the handler mechanism. The “chicken foot” connector means that this arrow accesses just one field in an array: such an arrow could connect e.g. a input field of type old_a: A in a structure Vec<(A,B)> to an output new_a: A, which just means that we are inside a for loop and this computation is done for all the elemnts in the vector/array.

![Figure](/img/pickles_structure_drawio.png)

## Consensus

Mina employs [Ouroboros Samasika](https://eprint.iacr.org/2020/352.pdf) as its consensus mechanism, which will be subsequently denoted as Samasika.
Three essential commitments provided include:

- High decentralization - Self-bootstrap, uncapped participation and dynamic availability
- Succinctness - Constant-time synchronization with full-validation and high interoperability
- Universal composability - Proven security for interacting with other protocols, no slashing required

Joseph Bonneau, Izaak Meckler, Vanishree Rao, and Evan Shapiro collaborated to create Samasika, establishing it as the initial succinct blockchain consensus algorithm.  
The complexity of fully verifying the entire blockchain is independent of chain length.  
Samasika takes its name from the Sanskrit term, meaning small or succinct.

### Chain selection rules

Samasika uses two consensus rules: one for _short-range forks_ and one for _long-range forks_.

#### Short-range fork rule

This rule is triggered whenever the fork is such that the adversary has not yet had the opportunity to mutate the block density distribution.  
A fork is considered short-range if it took place within the last **m** blocks. The straightforward implementation of this rule involves consistently storing the most recent **m** blocks. Yet, in the context of a succinct blockchain, this is considered not desirable. Mina Samasika follows a methodology that necessitates information about only two blocks, the concept involves a decentralized checkpointing algorithm.

#### Long-range fork rule

When a malicious actor generates an long-range fork, it gradually distorts the leader selection distribution, resulting in a longer adversarial chain. At the start, the dishonest chain will have a reduced density, but eventually, the adversary will work to elevate it. Therefore, the only factor we can depend on is the variation in density in the initial slots after the fork, which is known as the _critical window_.  
The reasoning is that the critical window of the honest chain is very likely to have a higher density because this chain has the most stake

### Decentralized checkpointing

Samasika employs decentralized checkpointing to discern the nature of a fork, categorizing it as either short-range or long-range.

- **Start checkpoint** - State hash of the first block of the epoch.
- **Lock checkpoint** - State hash of the last known block in the seed update range of an epoch (not including the current block)

Remember, a fork is categorized as short-range if either:

- The fork point of the candidate chains are in the same epoch.
- The fork point is in the previous epoch with the same ``lock_checkpoint``

As Mina prioritizes succinctness, it implies the need to maintain checkpoints for both the current and the previous epoch.

### Short-range fork check

Keep in mind that short-range forks occur when the fork point occurs after the lock_checkpoint of the previous epoch; otherwise, it qualifies as a long-range fork.  
The position of the previous epoch is a measurement relative to a block's perspective. In cases where candidate blocks belong to distinct epochs, each will possess distinct current and previous epoch values.  
Alternatively, if the blocks belong to the same epoch, they will both reference the identical previous epoch. Thus we can simply check whether the blocks have the same lock_checkpoint in their previous epoch data.

### Sliding window density

Let describe Mina's succinct sliding window density algorithm used by the long-range fork rule. In detail how windows are represented in blocks and how to compute _minimum window density_

#### Nomenclature

- We say a slot is _filled_ if it contains a valid non-orphaned block.
- An _w-window_ is a sequential list of slots s1,...,sw of length _w_.
- A _sub-window_ is a contiguous interval of a _w-window_.
- The _density_ of an w-window (or sub-window) is the number non-orphan block within it.
- We use the terms _window_, _density window_, _sliding window_ and _w-window_ synonymously.
- v is the Length by which the window shifts in slots (shift parameter).  ``slots_per_sub_window``
- w is the Window length in slots.  ( the sliding window is a _w_-long window that shifts _v_-slots at a time).

The Samasika research paper presents security proofs that determine the secure values for v, w, and sub-windows per window.  
A sliding window can also be viewed as a collection of _sub-windows_.  
Rather than storing a window as clusters of slots, Samasika focuses solely on the density of each sub-window.  
The density of a window is computed as the sum of the densities of its sub-windows.

Given a window ``W`` that is a list of sub-window densities, the window density is: ``density(W) = sum(W)``

#### Window structure

We use the phrase "window at sub-window _s_" to refer to the window _W_ whose most recent global sub-window is _s_.  
In the Samasika paper the window structure actually consists of the **11 previous sub-window densities**, the **current sub-window density** and the **minimum window density** .A total of _13_ densities.  
The most recent sub-window may be a previous sub-window or the current sub-window.  

#### Minimum window density

The **minimum window density** at a given slot is defined as the minimum window density observed over all previous sub-windows and previous windows, all the way back to genesis.  
When a new block _B_ with parent _P_ is created, the minimum window density is computed like this.  
``B.min_window_density = min(P.min_window_density, current_window_density)``  
where ``current_window_density`` is the density of _B's_ projected window

The relative sub-window _i_ of a sub-window _sw_ is its index within the window.

#### Ring-shift

When we shift a window ``[d0, d1, ..., d10]`` in order to add in a new sub-window ``d11``, we could evict the oldest sub-window d0 by shifting down all of the other sub-windows. Unfortunately, shifting a list in a SNARK circuit is very expensive.  
It is more efficient (and also equivalent) to just replace the sub-window we wish to evict by overwriting it with the new sub-window, like this:
 ``sub_window_densities: d11 | d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8 | d9 | d10``

#### Projected window

Generating a new block and determining the optimal chain in accordance with the long-range fork rule involve the computation of a projected window.  
Given a window _W_ and a future global slot _next_, the projected window of _W_ to slot _next_ is a transformation of _W_ into what it would look like if it were positioned at slot _next_.  
For example, when a new block _B_ is produced with parent block _P_, the height of _B_ will be the height of _P_ plus one, but the global slot of _B_ will depend on how much time has elapsed since _P_ was created.  
According to the Samasika paper, the window of _B_ must be initialized based on _P's_ window, then shifted because _B_ is ahead of _P_ and finally the value of _B's_ sub-window is incremented to account for _B_ belonging to it.  
Remember that the calculation of window density, including sub-window s, only occurs when the sub-window is greater than s, after s becomes a previous sub-window.
Therefore, if _next_ is **k** sub-windows ahead of _W_ we must shift only **k - 1** times because we must keep the most recent previous sub-window.

Now that we know how much to ring-shift, the next question is what density values to shift in. Remember that when projecting W to global slot next, we said that there are no intermediate blocks. That is, all of the slots and sub-windows are empty between W's current slot and next. Consequently, we must ring-shift in zero densities. The resulting window W is the projected window.

Recall this diagram:

![consensus01](/img/consensus01.png)

Suppose window W's current sub-window is 11 whose density is d11 and d1 is the oldest sub-window density

Now imagine we want to project W to global slot ``next = 15``. This is ``k = 15 - 11 = 4`` sub-windows ahead of the most recent sub-window. Therefore, we compute ``shift_count = min(max(k - 1, 0), sub_windows_per_window)``  in this case: ``shift_count = min(max(4 - 1, 0), 11) = 3``

Ring-shift in 3 zero densities to obtain the projected window.

![consensus02](/img/consensus02.png)

We can derive some instructive cases from the general rule

![consensus03](/img/consensus03.png)

##### Genesis window

Anything related to Genesis windows is not involved in the Mina Bridge.

##### Relative minimum window density

When Mina engages "chain selection" in the long-range fork rule, It doesn't directly employ the minimum window densities found in  in the current and candidate blocks.  
Rather than that, Mina opts for the relative minimum window density...

Remember that the minimum window density consistently decreases. Consequently, if a peer has been offline for a while and wants to reconnect, their current best chain might exhibit a higher minimum window density compared to the canonical chain candidate.
Additionally, the long-range fork rule dictates that the peer to choose the chain with the superior minimum density.  
The calculation of the minimum window density does not take into account the relationship between the current best chain and the canonical chain with respect to time.  
Within Samasika, time is encapsulated and safeguarded by the notions of slots and the VRF. When computing the minimum window density, it is imperative to factor in these elements as well.  
The relative minimum window density solves this problem by projecting the joining peer's current block's window to the global slot of the candidate block.  

## Protocol

This section outlines the consensus protocol in terms of events. **Initialize consensus** and **Select chain**.

In the following description, dot notation is used to refer to the local data members of peers. For example, given peer P, we use P.genesis_block and P.tip, to refer to the genesis block and currently selected chain, respectively.  
For example, given peer ``P``, we use ``P.genesis_block`` and ``P.tip``, to refer to the genesis block and currently selected chain, respectively.

### Initialize consensus

Things a peer MUST do to initialize consensus includes are _Load the genesis block_, _Get the tip_, _Bootstrap_ and _Catchup_  
Bootstrapping consensus requires the ability to synchronize epoch ledgers from the network.  
All peers MUST have the ability to load both the staking epoch ledger and next epoch ledger from disk and by downloading them. P2P peers MUST also make these ledgers available for other peers.  

### Select chain

Each time a peer's chains receive an update, the select chain event takes place.  
A chain is said to be updated anytime a valid block is added or removed from its head. The chain selection algorithm also incorporates certain tiebreak logic.  
Supplementary tiebreak logic becomes necessary when assessing chains with identical length or equal minimum density.

Let ``P.tip`` refer to the top block of peer ``P``'s current best chain. Assuming an update to either ``P.tip`` or ``P.chains``, ``P`` must update its tip similar to this:

![consensus06](/img/consensus06.png)

The following selectSecureChain algorithm receives the peer's current best chain P.tip and its set of known valid chains P.chains and produces the most secure chain as output.  

![consensus07](/img/consensus07.png)

And the ``selectLongerChain`` algorithm:

![consensus08](/img/consensus08.png)

### Maintaining the k-th predecessor epoch ledger

The staking and next epoch ledgers MUST be finalized ledgers and can only advance when there is sufficient depth to achieve finality.  
The staking and next epoch ledgers must be in a finalized state and can progress only when there is enough depth to ensure finality. Peers are required to retain the epoch ledger of the k-th predecessor from the tip, where ``k`` represents the depth of finality.  
Due to the security prerequisites of Ouroboros, the gap in slots between the staking and next epoch ledgers may be great. Consequently, at any given moment, we essentially have three "pointers": staking ``s``, next ``n``, and finality ``k``.  
The ``final_ledger`` (epoch ledger of the k-th predecessor from the tip) is updated each time chain selection occurs, i.e., for every new tip block appended.  

### Getting the tip

For a joining peer to discover the head of the current chain it MUST not only obtain the tip, but also the min(k, tip.height - 1)-th block back from the tip. For the latter the peer MUST check the block's proof of finality.  
Peers perform the proof of finality check by verifying two zero-knowledge proofs, one for the _tip_ and one for the _root_, and a Merkle proof for the chain of protocol state hashes between them.
