import Basic
import Foundation
import TuistSupport
import XCTest

@testable import TuistTemplate
@testable import TuistSupportTesting

final class TemplatesDirectoryLocatorIntegrationTests: TuistTestCase {
    var subject: TemplatesDirectoryLocator!

    override func setUp() {
        super.setUp()
        subject = TemplatesDirectoryLocator()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_locate_when_a_templates_and_git_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Tuist/Templates", "this/.git"])

        // When
        let got = subject.locate(from: temporaryDirectory.appending(RelativePath("this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(RelativePath("this/is/Tuist/Templates")))
    }

    func test_locate_when_a_templates_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/is/Tuist/Templates"])

        // When
        let got = subject.locate(from: temporaryDirectory.appending(RelativePath("this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(RelativePath("this/is/Tuist/Templates")))
    }

    func test_locate_when_a_git_directory_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/.git"])

        // When
        let got = subject.locate(from: temporaryDirectory.appending(RelativePath("this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(RelativePath("this/Tuist/Templates")))
    }

    func test_locate_when_multiple_tuist_directories_exists() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/Tuist/", "this/is/Tuist/"])
        let paths = [
            "this/is/a/very/directory",
            "this/is/a/very/nested/directory",
        ]

        // When
        let got = paths.map {
            subject.locate(from: temporaryDirectory.appending(RelativePath($0)))
        }

        // Then
        XCTAssertEqual(got, [
            "this/is/Tuist/Templates",
            "this/is/a/very/nested/Tuist/Templates",
        ].map { temporaryDirectory.appending(RelativePath($0)) })
    }
    
    func test_locate_when_templates_directory_exist() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/very/nested/directory", "this/Templates"])
        // When
        let got = subject.locate(from: temporaryDirectory.appending(RelativePath("this/is/a/very/nested/directory")))

        // Then
        XCTAssertEqual(got, temporaryDirectory.appending(RelativePath("this/Templates")))
    }
    
    func test_locate_all_templates() throws {
        // Given
        let temporaryDirectory = try temporaryPath()
        try createFolders(["this/is/a/directory", "this/Templates/template_one", "this/Templates/template_two"])
        
        // When
        let got = try subject.templateDirectories(at: temporaryDirectory.appending(RelativePath("this/is/a/directory")))
        
        // Then
        XCTAssertEqual([
            AbsolutePath(#file.replacingOccurrences(of: "file://", with: ""))
                .appending(RelativePath("../../../../Templates/default")),
            temporaryDirectory.appending(RelativePath("this/Templates/template_one")),
            temporaryDirectory.appending(RelativePath("this/Templates/template_two")),
        ], got)
    }
}
