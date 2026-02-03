from python import Python, PythonObject


struct DinoV2Config:
    var architectures: String
    var attention_probs_dropout_prob: Float64
    var drop_path_rate: Float64
    var hidden_act: String
    var hidden_dropout_prob: Float64
    var hidden_size: Int
    var image_size: Int
    var initializer_range: Float64
    var layer_norm_eps: Float64
    var layerscale_value: Float64
    var mlp_ratio: Int
    var model_type: String
    var num_attention_heads: Int
    var num_channels: Int
    var num_hidden_layers: Int
    var patch_size: Int
    var qkv_bias: Bool
    var torch_dtype: String
    var transformers_version: String
    var use_swiglu_ffn: Bool


fn _get_i(d: PythonObject, key: String) raises -> Int:
    return Int(py=d[key])


fn _get_f(d: PythonObject, key: String) raises -> Float64:
    return Float64(py=d[key])


fn _get_b(d: PythonObject, key: String) raises -> Bool:
    return Bool(py=d[key])


fn _get_s(d: PythonObject, key: String) raises -> String:
    return String(d[key])


fn _get_s0(d: PythonObject, key: String) raises -> String:
    return String(d[key][0])


fn load_dinov2_config(path: String) raises -> DinoV2Config:
    var json = Python.import_module("json")
    var builtins = Python.import_module("builtins")
    var f = builtins.open(path, "r")
    var data = json.load(f)
    f.close()

    return DinoV2Config(
        architectures=_get_s0(data, "architectures"),
        attention_probs_dropout_prob=_get_f(data, "attention_probs_dropout_prob"),
        drop_path_rate=_get_f(data, "drop_path_rate"),
        hidden_act=_get_s(data, "hidden_act"),
        hidden_dropout_prob=_get_f(data, "hidden_dropout_prob"),
        hidden_size=_get_i(data, "hidden_size"),
        image_size=_get_i(data, "image_size"),
        initializer_range=_get_f(data, "initializer_range"),
        layer_norm_eps=_get_f(data, "layer_norm_eps"),
        layerscale_value=_get_f(data, "layerscale_value"),
        mlp_ratio=_get_i(data, "mlp_ratio"),
        model_type=_get_s(data, "model_type"),
        num_attention_heads=_get_i(data, "num_attention_heads"),
        num_channels=_get_i(data, "num_channels"),
        num_hidden_layers=_get_i(data, "num_hidden_layers"),
        patch_size=_get_i(data, "patch_size"),
        qkv_bias=_get_b(data, "qkv_bias"),
        torch_dtype=_get_s(data, "torch_dtype"),
        transformers_version=_get_s(data, "transformers_version"),
        use_swiglu_ffn=_get_b(data, "use_swiglu_ffn"),
    )
