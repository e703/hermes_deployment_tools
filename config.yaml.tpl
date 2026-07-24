model:
  default: ${DEFAULT_MODEL}
  provider: custom
  base_url: ${BASE_URL}
  api_key: "${BJLAB_API_KEY}"
  api_mode: chat_completions

custom_providers:
  - name: BJLAB
    base_url: ${BASE_URL}
    api_key: ${BJLAB_API_KEY}
    model: ${DEFAULT_MODEL}
    api_mode: chat_completions

