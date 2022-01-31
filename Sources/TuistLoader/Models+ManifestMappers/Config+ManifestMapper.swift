import Foundation
import ProjectDescription
import TSCBasic
import TSCUtility
import TuistCore
import TuistGraph
import TuistSupport

extension TuistGraph.Config {
    /// Maps a ProjectDescription.Config instance into a TuistGraph.Config model.
    /// - Parameters:
    ///   - manifest: Manifest representation of Tuist config.
    ///   - path: The path of the config file.
    static func from(manifest: ProjectDescription.Config, at path: AbsolutePath) throws -> TuistGraph.Config {
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        let generationOptions = try manifest.generationOptions.map {
            try TuistGraph.Config.GenerationOption.from(manifest: $0, generatorPaths: generatorPaths)
        }
        let compatibleXcodeVersions = TuistGraph.CompatibleXcodeVersions.from(manifest: manifest.compatibleXcodeVersions)
        let plugins = try manifest.plugins.map { try PluginLocation.from(manifest: $0, generatorPaths: generatorPaths) }
        let swiftVersion: TSCUtility.Version?
        if let configuredVersion = manifest.swiftVersion {
            swiftVersion = TSCUtility.Version(configuredVersion.major, configuredVersion.minor, configuredVersion.patch)
        } else {
            swiftVersion = nil
        }

        var cloud: TuistGraph.Cloud?
        if let manifestCloud = manifest.cloud {
            cloud = try TuistGraph.Cloud.from(manifest: manifestCloud)
        }

        var cache: TuistGraph.Cache?
        if let manifestCache = manifest.cache {
            cache = try TuistGraph.Cache.from(manifest: manifestCache, generatorPaths: generatorPaths)
        }

        if let forcedCacheDirectiory = forcedCacheDirectiory {
            cache = cache.map { TuistGraph.Cache(profiles: $0.profiles, path: forcedCacheDirectiory) }
                ?? TuistGraph.Cache(profiles: [], path: forcedCacheDirectiory)
        }

        return TuistGraph.Config(
            compatibleXcodeVersions: compatibleXcodeVersions,
            cloud: cloud,
            cache: cache,
            swiftVersion: swiftVersion,
            plugins: plugins,
            generationOptions: generationOptions,
            path: path
        )
    }

    private static var forcedCacheDirectiory: AbsolutePath? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.forceConfigCacheDirectory].map { AbsolutePath($0) }
    }
}

extension TuistGraph.Config.GenerationOption {
    /// Maps a ProjectDescription.Config.GenerationOptions instance into a TuistGraph.Config.GenerationOptions model.
    /// - Parameters:
    ///   - manifest: Manifest representation of Tuist config generation options
    ///   - generatorPaths: Generator paths.
    static func from(
        manifest: ProjectDescription.Config.GenerationOptions,
        generatorPaths: GeneratorPaths
    ) throws -> TuistGraph.Config.GenerationOption {
        switch manifest {
        case let .xcodeProjectName(templateString):
            return .xcodeProjectName(templateString.description)
        case let .organizationName(name):
            return .organizationName(name)
        case let .developmentRegion(developmentRegion):
            return .developmentRegion(developmentRegion)
        case .disableShowEnvironmentVarsInScriptPhases:
            return .disableShowEnvironmentVarsInScriptPhases
        case .resolveDependenciesWithSystemScm:
            return .resolveDependenciesWithSystemScm
        case .disablePackageVersionLocking:
            return .disablePackageVersionLocking
        case let .lastXcodeUpgradeCheck(version):
            return .lastUpgradeCheck(.init(version.major, version.minor, version.patch))
        }
    }
}
