use std::iter::zip;

use alloy::{
    primitives::{Bytes, FixedBytes},
    sol_types::sol,
};
use mina_p2p_messages::{
    bigint::BigInt,
    v2::{
        MinaBaseAccountBinableArgStableV2 as MinaAccount,
        MinaBaseAccountTimingStableV2 as MinaTiming, MinaBasePermissionsAuthRequiredStableV2,
        MinaNumbersGlobalSlotSinceGenesisMStableV1, MinaNumbersGlobalSlotSpanStableV1,
        PicklesBaseProofsVerifiedStableV1,
    },
};
use num_traits::ToPrimitive;
use MinaAccountValidationExample::*;

sol!(
    MinaAccountValidationExample,
    "abi/MinaAccountValidationExample.json"
);

#[allow(non_snake_case)]
impl TryFrom<&MinaAccount> for Account {
    type Error = String;

    fn try_from(value: &MinaAccount) -> Result<Self, Self::Error> {
        let MinaAccount {
            public_key,
            token_id,
            token_symbol,
            balance,
            nonce,
            receipt_chain_hash,
            delegate,
            voting_for,
            timing,
            permissions,
            zkapp,
        } = value;

        let publicKey = CompressedECPoint {
            x: FixedBytes::try_from(public_key.x.as_ref())
                .map_err(|err| format!("Could not convert public key x to FixedBytes: {err}"))?,
            isOdd: public_key.is_odd,
        };
        let tokenIdKeyHash = FixedBytes::try_from(token_id.0.as_ref())
            .map_err(|err| format!("Could not convert token id to FixedBytes: {err}"))?;

        let tokenSymbol: String = token_symbol
            .try_into()
            .map_err(|err| format!("Failed to convert token symbol to string: {err}"))?;
        let balance = balance.to_u64().ok_or("Failed to convert balance to u64")?;
        let nonce = nonce.to_u32().ok_or("Failed to convert nonce to u64")?;
        let receiptChainHash = FixedBytes::try_from(receipt_chain_hash.0.as_ref())
            .map_err(|err| format!("Could not convert token id to FixedBytes: {err}"))?;
        let delegate = if let Some(delegate) = delegate {
            CompressedECPoint {
                x: FixedBytes::try_from(delegate.x.as_ref())
                    .map_err(|err| format!("Could not delegate x to FixedBytes: {err}"))?,
                isOdd: delegate.is_odd,
            }
        } else {
            CompressedECPoint {
                x: FixedBytes::ZERO,
                isOdd: true,
            }
        };
        let votingFor = FixedBytes::try_from(voting_for.0.as_ref())
            .map_err(|err| format!("Could not convert voting_for to FixedBytes: {err}"))?;

        let timing = match timing {
            MinaTiming::Timed {
                initial_minimum_balance,
                cliff_time,
                cliff_amount,
                vesting_period,
                vesting_increment,
            } => Timing {
                initialMinimumBalance: initial_minimum_balance
                    .to_u64()
                    .ok_or("Failed to convert initial_minimum_balance to u64".to_string())?,
                cliffTime: match cliff_time {
                    MinaNumbersGlobalSlotSinceGenesisMStableV1::SinceGenesis(cliffTime) => {
                        cliffTime
                            .to_u32()
                            .ok_or("Failed to convert clif_time to u32")?
                    }
                },
                cliffAmount: cliff_amount
                    .to_u64()
                    .ok_or("Failed to convert cliff_amount to u64")?,
                vestingPeriod: match vesting_period {
                    MinaNumbersGlobalSlotSpanStableV1::GlobalSlotSpan(vesting_period) => {
                        vesting_period
                            .to_u32()
                            .ok_or("Failed to convert vesting_period to u32")?
                    }
                },
                vestingIncrement: vesting_increment
                    .to_u64()
                    .ok_or("Failed to convert vesting_increment to u64")?,
            },
            _ => Timing {
                initialMinimumBalance: 0,
                cliffTime: 0,
                cliffAmount: 0,
                vestingPeriod: 0,
                vestingIncrement: 0,
            },
        };
        let mina_to_sol_permissions =
            |permissions: MinaBasePermissionsAuthRequiredStableV2| match permissions {
                MinaBasePermissionsAuthRequiredStableV2::None => 0,
                MinaBasePermissionsAuthRequiredStableV2::Either => 1,
                MinaBasePermissionsAuthRequiredStableV2::Proof => 2,
                MinaBasePermissionsAuthRequiredStableV2::Signature => 3,
                MinaBasePermissionsAuthRequiredStableV2::Impossible => 4,
            };

        let permissions = Permissions {
            editState: mina_to_sol_permissions(permissions.edit_state.clone()),
            access: mina_to_sol_permissions(permissions.access.clone()),
            send: mina_to_sol_permissions(permissions.send.clone()),
            rreceive: mina_to_sol_permissions(permissions.receive.clone()),
            setDelegate: mina_to_sol_permissions(permissions.set_delegate.clone()),
            setPermissions: mina_to_sol_permissions(permissions.set_permissions.clone()),
            setVerificationKeyAuth: mina_to_sol_permissions(
                permissions.set_verification_key.0.clone(),
            ),
            setVerificationKeyUint: permissions
                .set_verification_key
                .1
                .to_u32()
                .ok_or("Failed to convert verification key uint to u32")?,
            setZkappUri: mina_to_sol_permissions(permissions.set_zkapp_uri.clone()),
            editActionState: mina_to_sol_permissions(permissions.edit_action_state.clone()),
            setTokenSymbol: mina_to_sol_permissions(permissions.set_token_symbol.clone()),
            incrementNonce: mina_to_sol_permissions(permissions.increment_nonce.clone()),
            setVotingFor: mina_to_sol_permissions(permissions.set_voting_for.clone()),
            setTiming: mina_to_sol_permissions(permissions.set_timing.clone()),
        };

        let zkapp = if let Some(zkapp) = zkapp {
            let mut appState: [FixedBytes<32>; 8] = [FixedBytes::ZERO; 8];
            for (state, new_state) in zip(zkapp.app_state.0 .0.clone(), appState.iter_mut()) {
                *new_state = FixedBytes::try_from(state.as_ref())
                    .map_err(|err| format!("Could not convert app state to FixedBytes: {err}"))?;
            }
            let verificationKey = if let Some(verification_key) = zkapp.verification_key.clone() {
                let mina_to_sol_proofs_verified =
                    |proofs_verified: PicklesBaseProofsVerifiedStableV1| match proofs_verified {
                        PicklesBaseProofsVerifiedStableV1::N0 => 0,
                        PicklesBaseProofsVerifiedStableV1::N1 => 1,
                        PicklesBaseProofsVerifiedStableV1::N2 => 2,
                    };
                let mina_to_sol_commitment =
                    |comm: (BigInt, BigInt)| -> Result<Commitment, String> {
                        Ok(Commitment {
                            x: FixedBytes::try_from(comm.0.as_ref()).map_err(|err| {
                                format!("Could not convert commitment x to FixedBytes: {err}")
                            })?,
                            y: FixedBytes::try_from(comm.1.as_ref()).map_err(|err| {
                                format!("Could not convert commitment y to FixedBytes: {err}")
                            })?,
                        })
                    };

                let wrap_index = verification_key.wrap_index;

                let mut sigmaComm: [Commitment; 7] = std::array::from_fn(|_| Commitment {
                    x: FixedBytes::ZERO,
                    y: FixedBytes::ZERO,
                });
                for (comm, new_comm) in zip(wrap_index.sigma_comm.iter(), sigmaComm.iter_mut()) {
                    *new_comm = mina_to_sol_commitment(comm.clone())?;
                }

                let mut coefficientsComm: [Commitment; 15] = std::array::from_fn(|_| Commitment {
                    x: FixedBytes::ZERO,
                    y: FixedBytes::ZERO,
                });
                for (comm, new_comm) in zip(
                    wrap_index.coefficients_comm.iter(),
                    coefficientsComm.iter_mut(),
                ) {
                    *new_comm = mina_to_sol_commitment(comm.clone())?;
                }

                let wrapIndex = WrapIndex {
                    sigmaComm,
                    coefficientsComm,
                    genericComm: mina_to_sol_commitment(wrap_index.generic_comm)?,
                    psmComm: mina_to_sol_commitment(wrap_index.psm_comm)?,
                    completeAddComm: mina_to_sol_commitment(wrap_index.complete_add_comm)?,
                    mulComm: mina_to_sol_commitment(wrap_index.mul_comm)?,
                    emulComm: mina_to_sol_commitment(wrap_index.emul_comm)?,
                    endomulScalarComm: mina_to_sol_commitment(wrap_index.endomul_scalar_comm)?,
                };
                VerificationKey {
                    maxProofsVerified: mina_to_sol_proofs_verified(
                        verification_key.max_proofs_verified,
                    ),
                    actualWrapDomainSize: mina_to_sol_proofs_verified(
                        verification_key.actual_wrap_domain_size,
                    ),
                    wrapIndex,
                }
            } else {
                // Empty VerificationKey

                let commitment_zero = Commitment {
                    x: FixedBytes::ZERO,
                    y: FixedBytes::ZERO,
                };
                let sigmaComm: [Commitment; 7] = std::array::from_fn(|_| commitment_zero.clone());

                let coefficientsComm: [Commitment; 15] =
                    std::array::from_fn(|_| commitment_zero.clone());

                let wrapIndex = WrapIndex {
                    sigmaComm,
                    coefficientsComm,
                    genericComm: commitment_zero.clone(),
                    psmComm: commitment_zero.clone(),
                    completeAddComm: commitment_zero.clone(),
                    mulComm: commitment_zero.clone(),
                    emulComm: commitment_zero.clone(),
                    endomulScalarComm: commitment_zero.clone(),
                };
                VerificationKey {
                    maxProofsVerified: 0,
                    actualWrapDomainSize: 0,
                    wrapIndex,
                }
            };
            let mut actionState: [FixedBytes<32>; 5] = [FixedBytes::ZERO; 5];
            for (state, new_state) in zip(zkapp.action_state.iter(), actionState.iter_mut()) {
                *new_state = FixedBytes::try_from(state.as_ref()).map_err(|err| {
                    format!("Could not convert action state to FixedBytes: {err}")
                })?;
            }
            ZkappAccount {
                appState,
                verificationKey,
                zkappVersion: zkapp
                    .zkapp_version
                    .to_u32()
                    .ok_or("Failed to convert zkapp version to u32".to_string())?,
                actionState,
                lastActionSlot: match zkapp.last_action_slot {
                    MinaNumbersGlobalSlotSinceGenesisMStableV1::SinceGenesis(last_action_slot) => {
                        last_action_slot
                            .to_u32()
                            .ok_or("Failed to convert zkapp version to u32".to_string())?
                    }
                },
                provedState: zkapp.proved_state,
                zkappUri: zkapp.zkapp_uri.0.clone().into(),
            }
        } else {
            // Empty ZkappAccount

            let commitment_zero = Commitment {
                x: FixedBytes::ZERO,
                y: FixedBytes::ZERO,
            };
            let sigmaComm: [Commitment; 7] = std::array::from_fn(|_| commitment_zero.clone());

            let coefficientsComm: [Commitment; 15] =
                std::array::from_fn(|_| commitment_zero.clone());

            let wrapIndex = WrapIndex {
                sigmaComm,
                coefficientsComm,
                genericComm: commitment_zero.clone(),
                psmComm: commitment_zero.clone(),
                completeAddComm: commitment_zero.clone(),
                mulComm: commitment_zero.clone(),
                emulComm: commitment_zero.clone(),
                endomulScalarComm: commitment_zero.clone(),
            };

            ZkappAccount {
                appState: [FixedBytes::ZERO; 8],
                verificationKey: VerificationKey {
                    maxProofsVerified: 0,
                    actualWrapDomainSize: 0,
                    wrapIndex,
                },
                zkappVersion: 0,
                actionState: [FixedBytes::ZERO; 5],
                lastActionSlot: 0,
                provedState: false,
                zkappUri: Bytes::new(),
            }
        };

        Ok(Account {
            publicKey,
            tokenIdKeyHash,
            tokenSymbol,
            balance,
            nonce,
            receiptChainHash,
            delegate,
            votingFor,
            timing,
            permissions,
            zkapp,
        })
    }
}
