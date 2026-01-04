import Foundation
import MLX
import MLXNN

/// Simple KV cache for transformer models
public class KVCache {
    var keys: MLXArray?
    var values: MLXArray?

    public var offset: Int {
        keys?.dim(2) ?? 0
    }

    public init() {}

    public func update(keys: MLXArray, values: MLXArray) -> (MLXArray, MLXArray) {
        if let existingKeys = self.keys, let existingValues = self.values {
            self.keys = concatenated([existingKeys, keys], axis: 2)
            self.values = concatenated([existingValues, values], axis: 2)
        } else {
            self.keys = keys
            self.values = values
        }
        return (self.keys!, self.values!)
    }
}

/// Create attention mask for transformer
public func createAttentionMask(h: MLXArray, cache: [KVCache]?) -> MLXArray? {
    let T = h.dim(1)
    if T <= 1 {
        return nil
    }

    // Create causal mask
    let indices = MLXArray(0..<T)
    let mask = indices.expandedDimensions(axis: 0) .>= indices.expandedDimensions(axis: 1)

    // Convert to bfloat16 (matching the model dtype) and apply -inf for masked positions
    let dtype = h.dtype
    let zero = MLXArray(Float(0)).asType(dtype)
    let negInf = MLXArray(Float(-1e9)).asType(dtype)

    return MLX.where(mask, zero, negInf)
}
