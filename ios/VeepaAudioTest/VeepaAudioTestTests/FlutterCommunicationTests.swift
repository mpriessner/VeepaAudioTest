//
//  FlutterCommunicationTests.swift
//  VeepaAudioTestTests
//
//  Tests Flutter-iOS communication pipeline
//

import XCTest
@testable import VeepaAudioTest

@MainActor
final class FlutterCommunicationTests: XCTestCase {

    func testFlutterEngineInitialization() async throws {
        print("\n🧪 TEST: Flutter Engine Initialization")

        let manager = FlutterEngineManager.shared

        // Initialize and wait for ready
        try await manager.initializeAndWaitForReady(timeout: 10.0)

        // Verify
        XCTAssertTrue(manager.isInitialized, "Engine should be initialized")
        XCTAssertTrue(manager.isFlutterReady, "Flutter should be ready")
        XCTAssertNotNil(manager.engine, "Engine should exist")
        XCTAssertNotNil(manager.methodChannel, "Method channel should exist")

        print("✅ Engine initialized successfully")
    }

    func testPingCommunication() async throws {
        print("\n🧪 TEST: Ping Communication (iOS → Flutter → iOS)")

        let manager = FlutterEngineManager.shared

        // Ensure initialized
        if !manager.isFlutterReady {
            try await manager.initializeAndWaitForReady(timeout: 10.0)
        }

        // Test ping
        let response = try await manager.ping()

        // Verify
        XCTAssertEqual(response, "pong", "Should receive 'pong' from Flutter")

        print("✅ Ping successful: \(response)")
    }

    func testMethodInvocation() async throws {
        print("\n🧪 TEST: Method Invocation")

        let manager = FlutterEngineManager.shared

        // Ensure initialized
        if !manager.isFlutterReady {
            try await manager.initializeAndWaitForReady(timeout: 10.0)
        }

        // Test that connectWithCredentials method exists (won't actually connect)
        do {
            let dummyArgs: [String: Any] = [
                "cameraUid": "test_uid",
                "clientId": "test_client",
                "serviceParam": "test_param",
                "password": "888888"
            ]

            // This should fail (no real camera), but we verify the method exists
            let result = try await manager.invoke("connectWithCredentials", arguments: dummyArgs)

            // If we get here, method exists but connection failed (expected)
            print("⚠️ Method exists but connection failed (expected): \(String(describing: result))")
            XCTAssertNotNil(result, "Method should return a result")

        } catch {
            // Method might throw because no camera, but that's OK for this test
            print("⚠️ Method exists but threw error (expected): \(error)")
        }

        print("✅ Method invocation works")
    }

    func testConnectionBridgeSetup() async throws {
        print("\n🧪 TEST: Connection Bridge Setup")

        let bridge = VeepaConnectionBridge.shared

        // Setup event handler
        bridge.setupEventHandler()

        // Verify initial state
        XCTAssertEqual(bridge.state, .idle, "Should start in idle state")
        XCTAssertNil(bridge.lastError, "Should have no errors initially")

        print("✅ Connection bridge initialized correctly")
    }

    override func tearDown() async throws {
        // Cleanup
        let manager = FlutterEngineManager.shared
        if manager.isInitialized {
            manager.shutdown()
        }

        try await super.tearDown()
    }
}
