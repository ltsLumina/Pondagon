// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#include "SslSession.h"
#include "DiversionHttpModule.h"
#include "Types.h"

#include "Misc/Compression.h"
#include "Misc/ScopeLock.h"
#include "Containers/UnrealString.h"

#include <fstream>


using namespace DiversionHttp;

tcp_stream& FHttpSSLSession::TcpStream() {
	return beast::get_lowest_layer(Stream);
}

const tcp_stream& FHttpSSLSession::TcpStream() const {
	return beast::get_lowest_layer(Stream);
}

void FHttpSSLSession::Shutdown() {
	// Gracefully close the SSL connection
	if (TcpStream().socket().is_open())
	{
		beast::error_code ec;
		
		// Only attempt SSL shutdown if handshake was completed
		if (bSSLHandshakeCompleted.load())
		{
			// Synchronous SSL shutdown - simpler and avoids promise issues
			Stream.shutdown(ec);
			
			if (ec == boost::asio::error::eof)
			{
				// Rationale:
				// http://stackoverflow.com/questions/25587403/boost-asio-ssl-async-shutdown-always-finishes-with-an-error
				ec.assign(0, ec.category());
			}

			// ssl::error::stream_truncated, also known as an SSL "short read",
			// indicates the peer closed the connection without performing the
			// required closing handshake (for example, Google does this to
			// improve performance). Generally this can be a security issue,
			// but if your communication protocol is self-terminated (as
			// it is with both HTTP and WebSocket) then you may simply
			// ignore the lack of close_notify.
			//
			// https://github.com/boostorg/beast/issues/38
			//
			// https://security.stackexchange.com/questions/91435/how-to-handle-a-malicious-ssl-tls-shutdown
			//
			// When a short read would cut off the end of an HTTP message,
			// Beast returns the error beast::http::error::partial_message.
			// Therefore, if we see a short read here, it has occurred
			// after the message has been completed, so it is safe to ignore it.
			if (ec && ec != net::ssl::error::stream_truncated)
			{
				UE_LOG(LogDiversionHttp, Warning, TEXT("SSL Socket shutdown warning: %hs"), ec.message().c_str());
			}
		}

		// Always close the underlying TCP socket
		TcpStream().socket().shutdown(net::ip::tcp::socket::shutdown_both, ec);
		if (ec && ec != beast::errc::not_connected)
		{
			UE_LOG(LogDiversionHttp, Warning, TEXT("TCP socket shutdown warning: %hs"), ec.message().c_str());
		}
	}
}


std::future<bool> FHttpSSLSession::ConnectAsync()
{
	if (State.load() != ConnectionState::Disconnected)
	{
		std::promise<bool> immediate_promise;
		immediate_promise.set_value(State.load() == ConnectionState::Connected);
		return immediate_promise.get_future();
	}

	State.store(ConnectionState::Connecting);
	connection_promise = std::promise<bool>{};
	auto connection_future = connection_promise.get_future();
	
	// Start with DNS resolution
	// Use bind_front_handler with SharedThis() to keep the session alive during async operation
	Resolver.async_resolve(
		Host,
		Port,
		beast::bind_front_handler(&FHttpSSLSession::OnSSLResolveForConnection, SharedThis()));

	return connection_future;
}

HTTPCallResponse FHttpSSLSession::ExecuteRequest(const http::request<http::string_body>& InRequest, FString InOutputFilePath)
{
	// SSL sessions can use the base class request logic once connected
	return FHttpSession<ssl_stream>::ExecuteRequest(InRequest, InOutputFilePath);
}

void FHttpSSLSession::OnSSLResolveForConnection(beast::error_code ec, net::ip::tcp::resolver::results_type results)
{
	if (ec) {
		UE_LOG(LogDiversionHttp, Error, TEXT("SSL DNS resolution failed for %s:%s - %s"), 
			   UTF8_TO_TCHAR(Host.c_str()), UTF8_TO_TCHAR(Port.c_str()), UTF8_TO_TCHAR(ec.message().c_str()));
		State.store(ConnectionState::Failed);
		connection_promise.set_value(false);
		return;
	}

	// Set a timeout on the operation
	TcpStream().expires_after(ConnectionTimeout);
	// Use bind_front_handler with SharedThis() to keep the session alive during async operation
	TcpStream().async_connect(results,
		beast::bind_front_handler(&FHttpSSLSession::OnSSLTcpConnected, SharedThis()));
}

void FHttpSSLSession::OnSSLTcpConnected(beast::error_code ec, net::ip::tcp::resolver::results_type::endpoint_type)
{
	if (ec) {
		LogTimeoutErrorIfExists(ec);
		State.store(ConnectionState::Failed);
		connection_promise.set_value(false);
		return;
	}

	EnableSocketKeepAlive();

	// TCP connected, now perform SSL handshake
	if (!SSL_set_tlsext_host_name(Stream.native_handle(), Host.c_str()))
	{
		boost::system::error_code ssl_ec{ static_cast<int>(::ERR_get_error()), boost::asio::error::get_ssl_category() };
		UE_LOG(LogDiversionHttp, Error, TEXT("SSL SNI setup failed for %s:%s - %s"),
			   UTF8_TO_TCHAR(Host.c_str()), UTF8_TO_TCHAR(Port.c_str()), UTF8_TO_TCHAR(ssl_ec.message().c_str()));
		State.store(ConnectionState::Failed);
		connection_promise.set_value(false);
		return;
	}

	// Use bind_front_handler with SharedThis() to keep the session alive during async operation
	Stream.async_handshake(net::ssl::stream_base::client,
		beast::bind_front_handler(&FHttpSSLSession::OnSSLHandshakeComplete, SharedThis()));
}

void FHttpSSLSession::OnSSLHandshakeComplete(beast::error_code ec)
{
	if (ec) {
		UE_LOG(LogDiversionHttp, Error, TEXT("SSL handshake failed for %s:%s - %s"),
			   UTF8_TO_TCHAR(Host.c_str()), UTF8_TO_TCHAR(Port.c_str()), UTF8_TO_TCHAR(ec.message().c_str()));
		State.store(ConnectionState::Failed);
		connection_promise.set_value(false);
		return;
	}

	// Mark handshake as completed for proper shutdown handling
	bSSLHandshakeCompleted.store(true);
	State.store(ConnectionState::Connected);
	connection_promise.set_value(true);
}

void FHttpSSLSession::PerformRequest() {
	// SSL handshake already completed during ConnectAsync()
	// Just execute the request
	TcpStream().expires_after(RequestTimeout);
	http::async_write(Stream, Request, beast::bind_front_handler(&FHttpSession::OnWrite, shared_from_this()));
}
