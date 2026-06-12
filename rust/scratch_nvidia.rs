use reqwest;

#[tokio::main]
async fn main() {
    let api_key = std::env::var("NVIDIA_API_KEY").unwrap_or_else(|_| "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".to_string());
    let client = reqwest::Client::new();
    let res = client.post("https://integrate.api.nvidia.com/v1/chat/completions")
        .header("Authorization", format!("Bearer {}", api_key))
        .json(&serde_json::json!({
            "model": "z-ai/glm-5.1",
            "messages": [{"role": "user", "content": "hello"}],
            "stream": true,
            "max_tokens": 100
        }))
        .send()
        .await
        .unwrap();

    println!("Status: {}", res.status());
    println!("Headers: {:?}", res.headers());
    let bytes = res.bytes().await.unwrap();
    println!("Body: {}", String::from_utf8_lossy(&bytes));
}
