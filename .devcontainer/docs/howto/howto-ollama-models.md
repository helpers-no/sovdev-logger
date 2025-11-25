# Using Local Ollama Models in DevContainer

**Purpose**: Access free, local AI coding models running on your Mac through LiteLLM proxy

**Target Audience**: Developers working in DevContainers who want to use local AI models for coding assistance

**Prerequisites**:
- Ollama installed on Mac host
- LiteLLM configured in K8s cluster
- nginx reverse proxy running in DevContainer
- API key configured (`$ANTHROPIC_AUTH_TOKEN`)

---

## Overview

Your DevContainer can access **free, local AI coding models** running on your Mac through the LiteLLM proxy. These models run entirely on your local hardware, incurring no API costs.

### Available Models

| Model | Size | Focus | Best For |
|-------|------|-------|----------|
| **qwen2.5-coder:7b** | 4.7GB | Detailed coding, multilingual | Learning, comprehensive explanations |
| **deepseek-coder:6.7b** | 3.8GB | Concise code generation | Quick answers, production code |

Both models are optimized for programming tasks and support multiple languages.

---

## Quick Start

### Test All Available Models

```bash
# Check your access and test all models
.devcontainer/additions/cmd-ai.sh --test-all
```

**Expected Output**:
```
════════════════════════════════════════════════════════
🧪 Testing All Models
════════════════════════════════════════════════════════

Model                                    Status
-----                                    ------
qwen2.5-coder:7b                         ✅ OK
deepseek-coder:6.7b                      ✅ OK
claude-sonnet-4-5-20250929               ⚠️  (requires credits)
claude-3-opus-20240229                   ⚠️  (requires credits)
```

### Check Your Usage and Budget

```bash
# See your LiteLLM info and spending
.devcontainer/additions/cmd-ai.sh --info
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ DevContainer                                            │
│                                                         │
│  ┌──────────────┐    ┌─────────────────┐              │
│  │ Your Code    │───▶│ LiteLLM Client  │              │
│  │ Claude Code  │    │ localhost:8080  │              │
│  └──────────────┘    └────────┬────────┘              │
│                                │                        │
│                       ┌────────▼────────┐              │
│                       │ Nginx Proxy     │              │
│                       │ (adds Host:)    │              │
│                       └────────┬────────┘              │
└────────────────────────────────┼────────────────────────┘
                                 │
                                 │ host.docker.internal
                                 │
┌────────────────────────────────▼────────────────────────┐
│ Mac Host                                                │
│                                                         │
│  ┌──────────────┐    ┌─────────────────┐              │
│  │ Ollama       │    │ K8s Cluster     │              │
│  │ localhost:   │◀───│ LiteLLM Proxy   │              │
│  │ 11434        │    │ (routes via     │              │
│  │              │    │  Traefik)       │              │
│  │ Models:      │    └─────────────────┘              │
│  │ - qwen2.5    │                                      │
│  │ - deepseek   │                                      │
│  └──────────────┘                                      │
└─────────────────────────────────────────────────────────┘
```

### How It Works

1. **Your code** makes API request to `http://localhost:8080`
2. **Nginx proxy** adds `Host: litellm.localhost` header
3. **Request forwarded** to Mac host via `host.docker.internal`
4. **Traefik** routes to LiteLLM service based on Host header
5. **LiteLLM** validates your key and forwards to Ollama
6. **Ollama** runs the model locally and returns response
7. **Response flows back** through LiteLLM → Traefik → nginx → your code

---

## Using Models in Your Code

### Python Example

```python
from openai import OpenAI

# Configure client for local LiteLLM
client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key=os.environ["ANTHROPIC_AUTH_TOKEN"]
)

# Use Qwen Coder for detailed explanations
response = client.chat.completions.create(
    model="qwen2.5-coder:7b",
    messages=[
        {"role": "user", "content": "Explain async/await in Python"}
    ]
)
print(response.choices[0].message.content)

# Use DeepSeek Coder for quick code generation
response = client.chat.completions.create(
    model="deepseek-coder:6.7b",
    messages=[
        {"role": "user", "content": "Write a binary search function"}
    ]
)
print(response.choices[0].message.content)
```

### Shell Example

```bash
# Test Qwen Coder model
curl http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "messages": [{"role": "user", "content": "Write a Python function to reverse a string"}],
    "max_tokens": 200
  }' | jq -r '.choices[0].message.content'

# Test DeepSeek Coder model
curl http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-coder:6.7b",
    "messages": [{"role": "user", "content": "Write a Python function to reverse a string"}],
    "max_tokens": 200
  }' | jq -r '.choices[0].message.content'
```

---

## Model Comparison

### Qwen 2.5 Coder (7B)

**Characteristics**:
- Detailed explanations with multiple approaches
- Includes examples, edge cases, and best practices
- Good for learning and understanding concepts
- Slightly slower but more comprehensive

**Example Response Style**:
```python
def reverse_string(s: str) -> str:
    """
    Reverse a string using slicing.

    Examples:
        >>> reverse_string("hello")
        'olleh'
    """
    # Method 1: Using slicing (most Pythonic)
    return s[::-1]

    # Method 2: Using reversed() and join
    # return ''.join(reversed(s))

    # Method 3: Manual iteration (educational)
    # result = []
    # for char in s:
    #     result.insert(0, char)
    # return ''.join(result)
```

### DeepSeek Coder (6.7B)

**Characteristics**:
- Concise, production-ready code
- Focuses on efficient solutions
- Good for quick answers and implementation
- Faster responses

**Example Response Style**:
```python
def reverse_string(s: str) -> str:
    return s[::-1]

print(reverse_string("hello"))  # Output: olleh
```

---

## Managing Ollama Models on Your Mac

### List Installed Models

```bash
# On your Mac (not in DevContainer)
ollama list
```

**Output**:
```
NAME                   ID              SIZE      MODIFIED
deepseek-coder:6.7b    ce298d984115    3.8 GB    2 hours ago
qwen2.5-coder:7b       dae161e27b0e    4.7 GB    4 hours ago
```

### Install New Models

```bash
# Browse available models
open https://ollama.com/library

# Pull a specific model
ollama pull qwen2.5-coder:7b
ollama pull deepseek-coder:6.7b

# Pull other coding models
ollama pull codellama:7b
ollama pull starcoder2:7b
```

### Remove Models

```bash
# Remove a model you don't need
ollama rm model-name:tag

# Check disk space savings
ollama list
```

### Test Model Locally

```bash
# Test a model directly on Mac
ollama run qwen2.5-coder:7b "Write a Python function to calculate factorial"
```

---

## Configuration Reference

### Environment Variables

These are automatically configured in your DevContainer:

```bash
# LiteLLM endpoint (via nginx proxy)
ANTHROPIC_BASE_URL="http://localhost:8080"

# Your LiteLLM API key
ANTHROPIC_AUTH_TOKEN="sk-litellm-xxxxx"

# Custom headers for routing
ANTHROPIC_CUSTOM_HEADERS='{"Host": "litellm.localhost"}'
```

### Configuration Files

- **cmd-ai.sh**: `.devcontainer/additions/cmd-ai.sh`
  - CLI tool for testing models and checking usage

- **Nginx config**: `.devcontainer/additions/nginx/litellm-proxy.conf`
  - Reverse proxy routing to LiteLLM

- **LiteLLM config**: Managed in K8s cluster
  - Model definitions and routing rules

---

## Troubleshooting

### Models Return Empty Content

**Symptom**: API call succeeds but response content is empty

**Diagnosis**:
```bash
# Test direct Ollama connection (on Mac)
curl http://localhost:11434/api/generate \
  -d '{"model": "qwen2.5-coder:7b", "prompt": "Say hello", "stream": false}'
```

**Common Causes**:
1. Model not loaded in Ollama
2. Network connectivity issue (nginx/Traefik)
3. Wrong model name in LiteLLM config

**Solution**:
```bash
# Check Ollama is running
ollama ps

# Check model exists
ollama list

# Load model manually
ollama run qwen2.5-coder:7b "test"

# Test from DevContainer
.devcontainer/additions/cmd-ai.sh --test-all
```

### Model Not Listed

**Symptom**: Model shows in `ollama list` but not available in DevContainer

**Cause**: Model not registered in LiteLLM configuration

**Solution**: LiteLLM requires manual model registration (no auto-discovery). Contact cluster admin to add new models to LiteLLM config.

### Slow Responses

**Symptom**: Model takes long time to respond

**Diagnosis**:
```bash
# Check Mac resource usage
top -l 1 | grep -E "CPU|PhysMem"

# Check if model is already loaded
ollama ps
```

**Common Causes**:
1. Model not pre-loaded (first request loads it)
2. System low on RAM (swap thrashing)
3. Other processes consuming resources

**Solution**:
```bash
# Pre-load model to keep in memory
ollama run qwen2.5-coder:7b ""

# Check available RAM (need ~5-8GB free for 7B models)
vm_stat | awk '/free/ {print $3}' | sed 's/\.//'

# Close unnecessary applications
```

### 401 Unauthorized

**Symptom**: API returns 401 authentication error

**Diagnosis**:
```bash
# Check if token is set
echo $ANTHROPIC_AUTH_TOKEN

# Check token validity
.devcontainer/additions/cmd-ai.sh --info
```

**Solution**:
```bash
# Re-run configuration
bash .devcontainer/additions/config-claude-code.sh

# Or manually set token
export ANTHROPIC_AUTH_TOKEN="sk-litellm-xxxxx"
```

---

## Cost Comparison

### Local Ollama Models (FREE)

| Model | Cost | Requirements |
|-------|------|--------------|
| qwen2.5-coder:7b | $0 | 8GB RAM, 5GB disk |
| deepseek-coder:6.7b | $0 | 8GB RAM, 4GB disk |

**Benefits**:
- No API costs
- No rate limits
- Data stays local (privacy)
- Works offline

**Trade-offs**:
- Uses local compute resources
- Slightly slower than cloud models
- Lower quality than Claude/GPT-4

### Cloud Models (PAID)

| Model | Cost per 1M tokens | Use Case |
|-------|-------------------|----------|
| Claude Sonnet 4.5 | ~$3-15 | Complex reasoning, architecture |
| Claude Opus | ~$15-75 | Highest quality, critical code |

**When to use cloud**:
- Complex architectural decisions
- Security-critical code review
- Production system design
- When you need the absolute best quality

**Recommendation**: Use local models for day-to-day coding, cloud models for critical decisions.

---

## Best Practices

### Model Selection

```bash
# Quick code snippets → DeepSeek
"Write a function to..."
"How do I..."

# Understanding concepts → Qwen
"Explain how..."
"What's the difference between..."

# Complex architecture → Claude (paid)
"Design a system that..."
"Review this security implementation..."
```

### Resource Management

```bash
# Keep frequently-used models loaded
ollama ps  # Check what's running

# Stop models when done with intensive work
# (Ollama auto-manages this, but you can force-quit)
pkill ollama && ollama serve &
```

### Cost Optimization

```bash
# Check your spending
.devcontainer/additions/cmd-ai.sh --info

# Strategy:
# 1. Use free Ollama models for 80% of coding tasks
# 2. Reserve Claude for complex problems
# 3. Monitor usage regularly
```

---

## Related Documentation

- **cmd-ai.sh Guide**: `.devcontainer/additions/cmd-ai.sh --help`
- **Nginx Proxy Setup**: `.devcontainer/additions/nginx/README-nginx.md`
- **LiteLLM Configuration**: `terchris/litellm-claude/DEVCONTAINER-LITELLM-COMMANDS.md`
- **Claude Code Setup**: `.devcontainer/additions/config-claude-code.sh`

---

## Quick Reference

**Test models**:
```bash
.devcontainer/additions/cmd-ai.sh --test-all
```

**Check usage**:
```bash
.devcontainer/additions/cmd-ai.sh --info
```

**List models on Mac**:
```bash
ollama list
```

**Add new model**:
```bash
ollama pull model-name:tag
# Then contact cluster admin to register in LiteLLM
```

---

**Last Updated**: 2025-11-25
**Maintained By**: DevContainer Toolbox Team
