import Foundation
import TSCBasic
import TuistCore
import TuistGraph
import TuistSupport

public protocol BuildGraphInspecting {
    /// Returns the build arguments to be used with the given target.
    /// - Parameter project: Project whose build arguments will be returned.
    /// - Parameter target: Target whose build arguments will be returned.
    /// - Parameter configuration: The configuration to be built. When nil, it defaults to the configuration specified in the scheme.
    /// - Parameter skipSigning: Skip code signing during build that is not required to be signed (eg. build for testing on iOS Simulator)
    func buildArguments(project: Project, target: Target, configuration: String?, skipSigning: Bool) -> [XcodeBuildArgument]

    /// Given a directory, it returns the first .xcworkspace found.
    /// - Parameter path: Found .xcworkspace.
    func workspacePath(directory: AbsolutePath) throws -> AbsolutePath?

    ///  From the list of buildable targets of the given scheme, it returns the first one.
    /// - Parameters:
    ///   - scheme: Scheme in which to look up the target.
    ///   - graphTraverser: GraphTraversing traverser.
    func buildableTarget(scheme: Scheme, graphTraverser: GraphTraversing) -> GraphTarget?

    ///  From the list of testable targets of the given scheme, it returns the first one.
    /// - Parameters:
    ///   - scheme: Scheme in which to look up the target.
    func testableTarget(scheme: Scheme, graphTraverser: GraphTraversing) -> GraphTarget?

    /// Given a graphTraverser, it returns a list of buildable schemes.
    func buildableSchemes(graphTraverser: GraphTraversing) -> [Scheme]

    /// Given a graphTraverser, it returns a list of buildable schemes that are part of the entry node
    func buildableEntrySchemes(graphTraverser: GraphTraversing) -> [Scheme]

    /// Given a graphTraverser, it returns a list of test schemes (those that include only one test target).
    func testSchemes(graphTraverser: GraphTraversing) -> [Scheme]

    /// Given a graphTraverser, it returns a list of testable schemes.
    func testableSchemes(graphTraverser: GraphTraversing) -> [Scheme]

    ///  From the list of runnable targets of the given scheme, it returns the first one.
    /// - Parameters:
    ///   - scheme: Scheme in which to look up the target.
    ///   - graphTraverser: GraphTraversing traverser.
    func runnableTarget(scheme: Scheme, graphTraverser: GraphTraversing) -> GraphTarget?

    /// Given a graphTraverser, it returns a list of runnable schemes.
    func runnableSchemes(graphTraverser: GraphTraversing) -> [Scheme]

    /// Schemes generated by `AutogeneratedWorkspaceSchemeWorkspaceMapper`
    func projectSchemes(graphTraverser: GraphTraversing) -> [Scheme]
}

public final class BuildGraphInspector: BuildGraphInspecting {
    public init() {}

    public func buildArguments(project: Project, target: Target, configuration: String?,
                               skipSigning: Bool) -> [XcodeBuildArgument]
    {
        var arguments: [XcodeBuildArgument]
        if target.platform == .macOS {
            arguments = [.sdk(target.platform.xcodeDeviceSDK)]
        } else {
            arguments = [.sdk(target.platform.xcodeSimulatorSDK!)]
        }

        // Configuration
        if let configuration = configuration {
            if (target.settings ?? project.settings)?.configurations.first(where: { $0.key.name == configuration }) != nil {
                arguments.append(.configuration(configuration))
            } else {
                logger
                    .warning(
                        "The scheme's targets don't have the given configuration \(configuration). Defaulting to the scheme's default."
                    )
            }
        }

        // Signing
        if skipSigning {
            arguments += [
                .xcarg("CODE_SIGN_IDENTITY", ""),
                .xcarg("CODE_SIGNING_REQUIRED", "NO"),
                .xcarg("CODE_SIGN_ENTITLEMENTS", ""),
                .xcarg("CODE_SIGNING_ALLOWED", "NO"),
            ]
        }

        return arguments
    }

    public func buildableTarget(scheme: Scheme, graphTraverser: GraphTraversing) -> GraphTarget? {
        guard
            scheme.buildAction?.targets.isEmpty == false,
            let buildTarget = scheme.buildAction?.targets.first
        else {
            return nil
        }

        return graphTraverser.target(
            path: buildTarget.projectPath,
            name: buildTarget.name
        )
    }

    public func testableTarget(scheme: Scheme, graphTraverser: GraphTraversing) -> GraphTarget? {
        guard let testTarget = scheme.testAction?.targets.first else { return nil }
        return graphTraverser.target(path: testTarget.target.projectPath, name: testTarget.target.name)
    }

    public func buildableSchemes(graphTraverser: GraphTraversing) -> [Scheme] {
        graphTraverser.schemes()
            .filter { $0.buildAction?.targets.isEmpty == false }
            .sorted(by: { $0.name < $1.name })
    }

    public func buildableEntrySchemes(graphTraverser: GraphTraversing) -> [Scheme] {
        let projects = Set(graphTraverser.rootTargets().map(\.project))
        return projects
            .flatMap(\.schemes)
            .filter { $0.buildAction?.targets.isEmpty == false }
            .sorted(by: { $0.name < $1.name })
    }

    public func testableSchemes(graphTraverser: GraphTraversing) -> [Scheme] {
        graphTraverser.schemes()
            .filter { $0.testAction?.targets.isEmpty == false }
            .sorted(by: { $0.name < $1.name })
    }

    public func testSchemes(graphTraverser: GraphTraversing) -> [Scheme] {
        graphTraverser.allTargets()
            .filter { $0.target.product == .unitTests || $0.target.product == .uiTests }
            .flatMap { target -> [Scheme] in
                target.project.schemes
                    .filter { $0.targetDependencies().map(\.name) == [target.target.name] }
            }
            .filter { $0.testAction?.targets.isEmpty == false }
            .sorted(by: { $0.name < $1.name })
    }

    public func runnableTarget(scheme: Scheme, graphTraverser: GraphTraversing) -> GraphTarget? {
        guard let runTarget = scheme.runAction?.executable else { return nil }
        return graphTraverser.target(
            path: runTarget.projectPath,
            name: runTarget.name
        )
    }

    public func runnableSchemes(graphTraverser: GraphTraversing) -> [Scheme] {
        graphTraverser.schemes()
            .filter { $0.runAction?.executable != nil }
            .sorted(by: { $0.name < $1.name })
    }

    public func projectSchemes(graphTraverser: GraphTraversing) -> [Scheme] {
        graphTraverser.workspace.schemes
            .filter { $0.name.contains("\(graphTraverser.workspace.name)-Workspace") }
            .sorted(by: { $0.name < $1.name })
    }

    public func workspacePath(directory: AbsolutePath) throws -> AbsolutePath? {
        try directory.glob("*.xcworkspace")
            .filter {
                try FileHandler.shared.contentsOfDirectory($0)
                    .map(\.basename)
                    .contains(Constants.tuistGeneratedFileName)
            }
            .first
    }
}
