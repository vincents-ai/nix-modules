use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;
use tokio::time::{timeout, Duration};

#[derive(Parser, Debug)]
#[command(name = "rust-microservice")]
#[command(author = "Vincents.ai")]
#[command(version = "0.1.0")]
#[command(about = "A demonstration Rust microservice", long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    Serve(ServeArgs),
    Health(HealthArgs),
}

#[derive(Parser, Debug, Clone)]
struct ServeArgs {
    #[arg(short, long, default_value = "8080")]
    port: u16,
    #[arg(short, long, default_value = "0.0.0.0")]
    host: String,
}

#[derive(Parser, Debug, Clone)]
struct HealthArgs {
    #[arg(short, long, default_value = "localhost")]
    host: String,
    #[arg(short, long, default_value = "8080")]
    port: u16,
    #[arg(short, long, default_value = "5")]
    timeout: u64,
}

struct SharedState {
    request_count: Arc<Mutex<u64>>,
}

impl SharedState {
    fn new() -> Self {
        Self {
            request_count: Arc::new(Mutex::new(0)),
        }
    }
}

async fn handle_connection(mut stream: TcpStream, state: &SharedState) -> Result<()> {
    let addr = stream.peer_addr().context("Failed to get peer address")?;

    let mut buf = [0u8; 1024];
    let bytes_read = stream.read(&mut buf).await.context("Failed to read from socket")?;

    if bytes_read == 0 {
        return Ok(());
    }

    let request = String::from_utf8_lossy(&buf[..bytes_read]);
    println!("Request from {}: {}", addr, request.lines().next().unwrap_or("unknown"));

    let mut count = state.request_count.lock().await;
    *count += 1;

    let response = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 80\r\n\r\n{{\"status\":\"healthy\",\"version\":\"0.1.0\",\"requests\":{}}}",
        count
    );

    stream.write_all(response.as_bytes()).await.context("Failed to write response")?;

    Ok(())
}

async fn serve(args: &ServeArgs) -> Result<()> {
    let addr: SocketAddr = format!("{}:{}", args.host, args.port)
        .parse()
        .context("Failed to parse address")?;

    let listener = TcpListener::bind(&addr)
        .await
        .context("Failed to bind to address")?;

    println!("Server listening on {}", addr);
    println!("Accepting connections...");

    let state = SharedState::new();

    loop {
        let (stream, _) = listener.accept().await.context("Failed to accept connection")?;
        let state = state.clone();
        let args = args.clone();
        tokio::spawn(async move {
            if let Err(e) = handle_connection(stream, &state).await {
                eprintln!("Error handling connection: {}", e);
            }
        });
    }
}

async fn health_check(args: &HealthArgs) -> Result<()> {
    let addr = format!("{}:{}", args.host, args.port);
    let timeout_duration = Duration::from_secs(args.timeout);

    match timeout(timeout_duration, TcpStream::connect(&addr)).await {
        Ok(Ok(_)) => {
            println!("Service is healthy");
            Ok(())
        }
        Ok(Err(e)) => {
            Err(anyhow::anyhow!("Connection failed: {}", e))
        }
        Err(_) => {
            Err(anyhow::anyhow!("Health check timed out after {} seconds", args.timeout))
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    match &args.command {
        Commands::Serve(serve_args) => serve(serve_args).await,
        Commands::Health(health_args) => health_check(health_args).await,
    }
}
