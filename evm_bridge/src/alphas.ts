/**
 * This type can be used to create a mapping between powers of alpha and constraint types.
 * See `default()` to create one,
 * and `register()` to register a new mapping.
 * Once you know the alpha value, you can convert this type to a `Alphas`.
*/
export class Alphas {
    /**
     * The next power of alpha to use.
     * The end result will be [1, alpha^(next_power - 1)]
     */
}
#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct Alphas<F> {
    /// The next power of alpha to use
    /// the end result will be [1, alpha^{next_power - 1}]
    next_power: u32,
    /// The mapping between constraint types and powers of alpha
    mapping: HashMap<ArgumentType, (u32, u32)>,
    /// The powers of alpha: 1, alpha, alpha^2, etc.
    /// If set to [Some], you can't register new constraints.
    alphas: Option<Vec<F>>,
}
