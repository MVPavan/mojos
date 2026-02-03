# MAX Framework

## Table of Contents
- [Overview](#overview)
- [MAX Serve](#max-serve)
- [Offline Inference](#offline-inference)
- [MAX Graph API](#max-graph-api)
- [Custom Operations](#custom-operations)
- [Deployment Patterns](#deployment-patterns)

## Overview

MAX (Modular Accelerated Xecution) is Modular's AI deployment framework:

- **MAX Engine**: Core inference runtime with MLIR-based optimization
- **MAX Serve**: Production server with OpenAI-compatible API
- **MAX Graph**: Python API for custom computational graphs
- **Custom Ops**: Extend MAX with Mojo-written operations

## MAX Serve

### Quick Start
```bash
# Install
pip install max-platform

# Serve a model
max serve --model modularai/Llama-3.1-8B-Instruct-GGUF

# With specific settings
max serve --model google/gemma-3-27b-it \
  --max-batch-size 32 \
  --max-cache-length 8192
```

### OpenAI-Compatible API
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"  # Not required for local
)

# Chat completion
response = client.chat.completions.create(
    model="modularai/Llama-3.1-8B-Instruct-GGUF",
    messages=[
        {"role": "system", "content": "You are helpful."},
        {"role": "user", "content": "Explain quantum computing."}
    ],
    max_tokens=512,
    temperature=0.7
)
print(response.choices[0].message.content)

# Streaming
stream = client.chat.completions.create(
    model="modularai/Llama-3.1-8B-Instruct-GGUF",
    messages=[{"role": "user", "content": "Write a poem"}],
    stream=True
)
for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

### Available Endpoints
- `POST /v1/chat/completions` - Chat interface
- `POST /v1/completions` - Text completion
- `POST /v1/embeddings` - Generate embeddings
- `GET /v1/models` - List available models

### Server Configuration
```bash
max serve \
  --model modularai/Llama-3.1-8B-Instruct-GGUF \
  --host 0.0.0.0 \
  --port 8000 \
  --tensor-parallelism 2 \      # Multi-GPU
  --max-batch-size 64 \
  --max-cache-length 16384 \
  --quantization q4_k           # Quantization level
```

## Offline Inference

For batch processing without a server:

```python
from max.pipelines import LLM, PipelineConfig

# Initialize model
config = PipelineConfig(
    max_length=2048,
    max_batch_size=8
)
llm = LLM(
    "modularai/Llama-3.1-8B-Instruct-GGUF",
    pipeline_config=config
)

# Generate single response
response = llm.generate("The capital of France is")
print(response)

# Batch generation
prompts = [
    "Explain machine learning in one sentence.",
    "What is the speed of light?",
    "Write a haiku about coding."
]
responses = llm.generate(prompts)
for prompt, response in zip(prompts, responses):
    print(f"Q: {prompt}")
    print(f"A: {response}\n")
```

### With Chat Messages
```python
from max.pipelines import LLM

llm = LLM("modularai/Llama-3.1-8B-Instruct-GGUF")

messages = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What is 2+2?"}
]

response = llm.chat(messages)
print(response)
```

## MAX Graph API

Build custom computational graphs:

```python
from max.graph import Graph, TensorType, ops
from max.dtype import DType

# Define input types
input_type = TensorType(dtype=DType.float32, shape=(None, 768))

# Build graph
with Graph("custom_mlp", input_types=[input_type]) as graph:
    x = graph.inputs[0]
    
    # Define operations
    x = ops.matmul(x, weights1)
    x = ops.relu(x)
    x = ops.matmul(x, weights2)
    x = ops.softmax(x, axis=-1)
    
    graph.output(x)

# Compile and run
from max.engine import InferenceSession

session = InferenceSession()
model = session.load(graph)
result = model.execute(input_tensor)
```

### Common Operations
```python
from max.graph import ops

# Element-wise
y = ops.add(a, b)
y = ops.mul(a, b)
y = ops.relu(x)
y = ops.sigmoid(x)
y = ops.tanh(x)

# Matrix operations
y = ops.matmul(a, b)
y = ops.transpose(x, perm=[0, 2, 1])

# Reductions
y = ops.reduce_sum(x, axis=-1)
y = ops.reduce_mean(x, axis=[1, 2])
y = ops.softmax(x, axis=-1)

# Shape operations
y = ops.reshape(x, shape=[batch, -1])
y = ops.concat([a, b], axis=0)
y = ops.split(x, num_splits=4, axis=1)
```

## Custom Operations

Extend MAX with high-performance Mojo operations:

### Define Custom Op
```mojo
# custom_relu.mojo
import compiler
from max.tensor import OutputTensor, InputTensor, foreach

@compiler.register("custom_relu")
struct CustomRelu:
    @staticmethod
    fn execute[target: StaticString](
        output: OutputTensor[dtype=DType.float32, rank=2],
        input: InputTensor[dtype=DType.float32, rank=2],
        ctx: DeviceContextPtr,
    ) raises:
        @parameter
        fn relu_op[width: Int](idx: Int):
            var val = input.load[width=width](idx)
            var zero = SIMD[DType.float32, width](0)
            output.store[width=width](idx, (val > zero).select(val, zero))
        
        foreach[relu_op](output, input)
```

### GPU Custom Op
```mojo
@compiler.register("gpu_vector_add")
struct GpuVectorAdd:
    @staticmethod
    fn execute[target: StaticString](
        output: OutputTensor[dtype=DType.float32, rank=1],
        a: InputTensor[dtype=DType.float32, rank=1],
        b: InputTensor[dtype=DType.float32, rank=1],
        ctx: DeviceContextPtr,
    ) raises:
        @parameter
        if target == "gpu":
            # GPU kernel
            fn kernel(
                out: UnsafePointer[Float32, MutAnyOrigin],
                a_ptr: UnsafePointer[Float32, MutAnyOrigin],
                b_ptr: UnsafePointer[Float32, MutAnyOrigin],
                size: Int
            ):
                var idx = global_idx.x
                if idx < size:
                    out[idx] = a_ptr[idx] + b_ptr[idx]
            
            var dev_ctx = ctx.get_device_context()
            dev_ctx.enqueue_function[kernel, kernel](
                output.unsafe_ptr(),
                a.unsafe_ptr(),
                b.unsafe_ptr(),
                output.dim(0),
                grid_dim=((output.dim(0) + 255) // 256,),
                block_dim=(256,)
            )
        else:
            # CPU fallback
            for i in range(output.dim(0)):
                output[i] = a[i] + b[i]
```

### Use Custom Op in Graph
```python
from max.graph import Graph, ops

with Graph("model_with_custom") as graph:
    x = graph.inputs[0]
    x = ops.custom("custom_relu", [x], output_types=[x.type])
    graph.output(x)
```

## Deployment Patterns

### Docker Deployment
```dockerfile
FROM modular/max-serving:latest

# Copy custom ops if any
COPY custom_ops/ /app/custom_ops/

# Set model
ENV MODEL_PATH="modularai/Llama-3.1-8B-Instruct-GGUF"

EXPOSE 8000
CMD ["max", "serve", "--model", "${MODEL_PATH}"]
```

### Multi-GPU Serving
```bash
# Tensor parallelism across 4 GPUs
max serve \
  --model modularai/Llama-3.3-70B-Instruct-GGUF \
  --tensor-parallelism 4
```

### Load Balancing Multiple Instances
```yaml
# docker-compose.yml
services:
  max-server-1:
    image: modular/max-serving:latest
    environment:
      - CUDA_VISIBLE_DEVICES=0
    command: max serve --model ${MODEL} --port 8001
    
  max-server-2:
    image: modular/max-serving:latest
    environment:
      - CUDA_VISIBLE_DEVICES=1
    command: max serve --model ${MODEL} --port 8002
    
  nginx:
    image: nginx:latest
    ports:
      - "8000:8000"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

### Health Checks
```python
import requests

def check_health(base_url="http://localhost:8000"):
    try:
        response = requests.get(f"{base_url}/health")
        return response.status_code == 200
    except:
        return False

def check_models(base_url="http://localhost:8000"):
    response = requests.get(f"{base_url}/v1/models")
    return response.json()["data"]
```

## Performance Tips

1. **Use quantization** for memory efficiency: `--quantization q4_k`

2. **Enable tensor parallelism** for large models across GPUs

3. **Tune batch size** based on your latency/throughput requirements

4. **Use speculative decoding** for faster generation (when supported)

5. **Monitor with** `/metrics` endpoint for Prometheus integration

6. **Pre-warm** the model by sending a few requests after startup
