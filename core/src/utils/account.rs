use kimchi::{mina_curves::pasta::Fp, o1_utils::FieldHelpers};
use mina_signer::CompressedPubKey;
use mina_tree::{
    proofs::transaction::{InnerCurve, PlonkVerificationKeyEvals},
    Account, AuthRequired, Permissions, ProofVerified, SetVerificationKey, Timing, VerificationKey,
    ZkAppAccount,
};

pub fn to_bytes(account: &Account) -> Vec<u8> {
    let mut ret = vec![];

    let public_key = public_key_to_bytes(&account.public_key);
    let token_id = account.token_id.0.to_bytes();
    let token_symbol = string_to_bytes(&account.token_symbol.0);
    let balance = account.balance.as_u64().to_be_bytes();
    let nonce = account.nonce.as_u32().to_be_bytes();
    let receipt_chain_hash = account.receipt_chain_hash.0.to_bytes();
    let delegate = option_public_key_to_bytes(&account.delegate);
    let voting_for = account.voting_for.0.to_bytes();
    let timing = timing_to_bytes(&account.timing);
    let permissions = permissions_to_bytes(&account.permissions);
    let zkapp = option_zk_app_account_to_bytes(&account.zkapp);

    let len = (public_key.len()
        + token_id.len()
        + token_symbol.len()
        + balance.len()
        + nonce.len()
        + receipt_chain_hash.len()
        + delegate.len()
        + voting_for.len()
        + timing.len()
        + permissions.len()
        + zkapp.len()) as u32;

    ret.extend(len.to_be_bytes());
    ret.extend(public_key);
    ret.extend(token_id);
    ret.extend(token_symbol);
    ret.extend(balance);
    ret.extend(nonce);
    ret.extend(receipt_chain_hash);
    ret.extend(delegate);
    ret.extend(voting_for);
    ret.extend(timing);
    ret.extend(permissions);
    ret.extend(zkapp);

    ret
}

fn public_key_to_bytes(public_key: &CompressedPubKey) -> Vec<u8> {
    let mut ret = vec![];

    ret.extend(public_key.x.to_bytes());
    ret.push(if public_key.is_odd { 1 } else { 0 });

    ret
}

fn option_public_key_to_bytes(public_key: &Option<CompressedPubKey>) -> Vec<u8> {
    let mut ret = vec![];

    match &public_key {
        Some(public_key) => {
            ret.push(1);
            ret.extend(public_key_to_bytes(public_key));
        }
        None => ret.push(0),
    }

    ret
}

fn string_to_bytes(string: &str) -> Vec<u8> {
    let mut ret = vec![];
    let bytes = string.as_bytes().to_vec();

    ret.extend((bytes.len() as u32).to_be_bytes());
    ret.extend(bytes);

    ret
}

fn timing_to_bytes(timing: &Timing) -> Vec<u8> {
    let mut ret = vec![];

    match timing {
        Timing::Untimed => ret.push(0),
        Timing::Timed {
            initial_minimum_balance,
            cliff_time,
            cliff_amount,
            vesting_period,
            vesting_increment,
        } => {
            ret.push(1);
            ret.extend(initial_minimum_balance.as_u64().to_be_bytes());
            ret.extend(cliff_time.as_u32().to_be_bytes());
            ret.extend(cliff_amount.as_u64().to_be_bytes());
            ret.extend(vesting_period.as_u32().to_be_bytes());
            ret.extend(vesting_increment.as_u64().to_be_bytes());
        }
    }

    ret
}

fn permissions_to_bytes(permissions: &Permissions<AuthRequired>) -> Vec<u8> {
    let mut ret = vec![
        auth_required_to_u8(&permissions.edit_state),
        auth_required_to_u8(&permissions.access),
        auth_required_to_u8(&permissions.send),
        auth_required_to_u8(&permissions.receive),
        auth_required_to_u8(&permissions.set_delegate),
        auth_required_to_u8(&permissions.set_permissions),
    ];

    ret.extend(set_verification_key_to_bytes(
        &permissions.set_verification_key,
    ));

    ret.push(auth_required_to_u8(&permissions.set_zkapp_uri));
    ret.push(auth_required_to_u8(&permissions.edit_action_state));
    ret.push(auth_required_to_u8(&permissions.set_token_symbol));
    ret.push(auth_required_to_u8(&permissions.increment_nonce));
    ret.push(auth_required_to_u8(&permissions.set_voting_for));
    ret.push(auth_required_to_u8(&permissions.set_timing));

    ret
}

fn auth_required_to_u8(auth_required: &AuthRequired) -> u8 {
    match auth_required {
        AuthRequired::None => 0,
        AuthRequired::Either => 1,
        AuthRequired::Proof => 2,
        AuthRequired::Signature => 3,
        AuthRequired::Impossible => 4,
        AuthRequired::Both => 5,
    }
}

fn set_verification_key_to_bytes(
    set_verification_key: &SetVerificationKey<AuthRequired>,
) -> Vec<u8> {
    let mut ret = vec![];

    ret.push(auth_required_to_u8(&set_verification_key.auth));
    ret.extend(set_verification_key.txn_version.as_u32().to_be_bytes());

    ret
}

fn option_zk_app_account_to_bytes(zk_app_account: &Option<Box<ZkAppAccount>>) -> Vec<u8> {
    let mut ret = vec![];

    match zk_app_account {
        Some(zk_app_account) => {
            ret.extend(
                zk_app_account
                    .app_state
                    .iter()
                    .flat_map(|fp| fp.to_bytes())
                    .collect::<Vec<_>>(),
            );
            ret.extend(option_verification_key_to_bytes(
                &zk_app_account.verification_key,
            ));
            ret.extend(zk_app_account.zkapp_version.to_be_bytes());
            ret.extend(
                zk_app_account
                    .action_state
                    .iter()
                    .flat_map(|fp| fp.to_bytes())
                    .collect::<Vec<_>>(),
            );
            ret.extend(zk_app_account.last_action_slot.as_u32().to_be_bytes());
            ret.push(if zk_app_account.proved_state { 1 } else { 0 });
            ret.extend(string_to_bytes(&zk_app_account.zkapp_uri));
        }
        None => ret.push(0),
    }

    ret
}

fn option_verification_key_to_bytes(verification_key: &Option<VerificationKey>) -> Vec<u8> {
    let mut ret = vec![];

    match verification_key {
        Some(verification_key) => {
            ret.push(proof_verified_to_u8(&verification_key.max_proofs_verified));
            ret.push(proof_verified_to_u8(
                &verification_key.actual_wrap_domain_size,
            ));
            ret.extend(plonk_verification_key_evals_to_bytes(
                &verification_key.wrap_index,
            ));
            ret.push(if verification_key.wrap_vk.is_some() {
                1
            } else {
                0
            });
        }
        None => ret.push(0),
    }

    ret
}

fn proof_verified_to_u8(proof_verified: &ProofVerified) -> u8 {
    match proof_verified {
        ProofVerified::N0 => 0,
        ProofVerified::N1 => 1,
        ProofVerified::N2 => 2,
    }
}

fn plonk_verification_key_evals_to_bytes(evals: &PlonkVerificationKeyEvals<Fp>) -> Vec<u8> {
    let mut ret = vec![];

    ret.extend(
        evals
            .sigma
            .iter()
            .flat_map(inner_curve_to_bytes)
            .collect::<Vec<_>>(),
    );
    ret.extend(
        evals
            .coefficients
            .iter()
            .flat_map(inner_curve_to_bytes)
            .collect::<Vec<_>>(),
    );
    ret.extend(inner_curve_to_bytes(&evals.generic));
    ret.extend(inner_curve_to_bytes(&evals.complete_add));
    ret.extend(inner_curve_to_bytes(&evals.mul));
    ret.extend(inner_curve_to_bytes(&evals.emul));
    ret.extend(inner_curve_to_bytes(&evals.endomul_scalar));

    ret
}

fn inner_curve_to_bytes(inner_curve: &InnerCurve<Fp>) -> Vec<u8> {
    let mut ret = vec![];
    let affine = inner_curve.to_affine();

    if affine.infinity {
        ret.push(1);
    } else {
        ret.push(0);
        ret.extend(affine.x.to_bytes());
        ret.extend(affine.y.to_bytes());
    }

    ret
}
