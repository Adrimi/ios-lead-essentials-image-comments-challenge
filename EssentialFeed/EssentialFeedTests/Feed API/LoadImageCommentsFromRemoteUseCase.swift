//
//  LoadImageCommentsFromRemoteUseCase.swift
//  EssentialFeedTests
//
//  Created by Adrian Szymanowski on 02/03/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import XCTest
import EssentialFeed

class RemoteImageCommentsLoader {
	typealias Result = Swift.Result<Any, Error>
	
	private let client: HTTPClient

	enum Error: Swift.Error {
		case connectivity
		case invalidData
	}
	
	init(client: HTTPClient) {
		self.client = client
	}
	
	func loadImageComments(from url: URL, completion: @escaping (Result) -> Void) {
		client.get(from: url) { [weak self] result in
			guard self != nil else { return }
			
			completion(result
				.mapError { _ in Error.connectivity}
				.flatMap { _ in .failure(Error.invalidData) })
		}
	}
}

class LoadImageCommentsFromRemoteUseCase: XCTestCase {
	
	func test_init_doesNotRequestDataFromURL() {
		let (_, client) = makeSUT()
		
		XCTAssertTrue(client.requestedURLs.isEmpty)
	}
	
	func test_loadImageComments_requestsDataFromURL() {
		let url = anyURL()
		let (sut, client) = makeSUT()
		
		sut.loadImageComments(from: url) { _ in }
		
		XCTAssertEqual(client.requestedURLs, [url])
	}
	
	func test_loadImageCommentsTwice_requestsImageCommentsTwice() {
		let url = anyURL()
		let (sut, client) = makeSUT()
		
		sut.loadImageComments(from: url) { _ in }
		sut.loadImageComments(from: url) { _ in }
		
		XCTAssertEqual(client.requestedURLs, [url, url])
	}
	
	func test_loadImageComments_deliversConnectivityErrorOnClientError() {
		let (sut, client) = makeSUT()
		let clientError = anyNSError()
		
		expect(sut, toCompleteWith: .failure(.connectivity), when: {
			client.complete(with: clientError)
		})
	}
	
	func test_loadImageComments_deliversInvalidDataErrorOnNon200HTTPResponse() {
		let (sut, client) = makeSUT()
		
		let samples = [199, 201, 300, 400, 500]
		
		samples.enumerated().forEach { index, code in
			expect(sut, toCompleteWith: .failure(.invalidData), when: {
				client.complete(withStatusCode: code, data: anyData(), at: index)
			})
		}
	}

	// MARK: - Helpers
	
	private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (sut: RemoteImageCommentsLoader, client: HTTPClientSpy) {
		let client = HTTPClientSpy()
		let sut = RemoteImageCommentsLoader(client: client)
		trackForMemoryLeaks(client, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		return (sut, client)
	}
	
	private func expect(_ sut: RemoteImageCommentsLoader, toCompleteWith expectedResult: RemoteImageCommentsLoader.Result, when action: () -> Void, file: StaticString = #file, line: UInt = #line) {
		let exp = expectation(description: "Wait for load comments completion")
		
		sut.loadImageComments(from: anyURL()) { receivedResult in
			switch (receivedResult, expectedResult) {
			case let (.failure(receivedError), .failure(expectedError)):
				XCTAssertEqual(receivedError, expectedError, file: file, line: line)
				
			default:
				XCTFail("Expected result \(expectedResult), got \(receivedResult) instead", file: file, line: line)
			}
			
			exp.fulfill()
		}
		
		action()
		
		wait(for: [exp], timeout: 1.0)
	}
	
}
