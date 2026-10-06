import ArgumentParser
import Foundation
import FoundationModels

struct SchemaCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Generate a structured output generation schema.",
        subcommands: [SchemaObjectCommand.self]
    )
}

struct SchemaObjectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "object",
        abstract: "Generate a structured output schema for an object type.",
        discussion: """
        Examples:
          fmx schema object --name Person --string name --int age
          fmx schema object --name Dog --string breed --boolean friendly -o dog.json
        """
    )

    @Option(help: "Schema / type name.")
    var name: String

    @Option(name: .customLong("string"), parsing: .unconditionalSingleValue, help: "String property name (repeatable).")
    var stringProperties: [String] = []

    @Option(name: .customLong("int"), parsing: .unconditionalSingleValue, help: "Integer property name (repeatable).")
    var intProperties: [String] = []

    @Option(name: .customLong("boolean"), parsing: .unconditionalSingleValue, help: "Boolean property name (repeatable).")
    var booleanProperties: [String] = []

    @Option(name: .customLong("number"), parsing: .unconditionalSingleValue, help: "Number (Double) property name (repeatable).")
    var numberProperties: [String] = []

    @Option(name: [.short, .customLong("output")], help: "Write schema JSON to this path instead of stdout.")
    var output: String?

    func run() throws {
        var properties: [SchemaPropertyDefinition] = []
        properties += stringProperties.map { SchemaPropertyDefinition(name: $0, type: .string) }
        properties += intProperties.map { SchemaPropertyDefinition(name: $0, type: .int) }
        properties += booleanProperties.map { SchemaPropertyDefinition(name: $0, type: .boolean) }
        properties += numberProperties.map { SchemaPropertyDefinition(name: $0, type: .number) }

        guard !properties.isEmpty else {
            Terminal.writeError("Add at least one property with --string, --int, --boolean, or --number.")
            throw ExitCode(2)
        }

        let definition = SchemaDefinition(name: name, properties: properties)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(definition)

        if let output {
            try data.write(to: URL(fileURLWithPath: output))
            Terminal.writeln("Wrote schema to \(output)")
        } else if let text = String(data: data, encoding: .utf8) {
            Terminal.writeln(text)
        }
    }
}

struct SchemaDefinition: Codable {
    var name: String
    var properties: [SchemaPropertyDefinition]

    func makeGenerationSchema() throws -> GenerationSchema {
        let dynamicProperties: [DynamicGenerationSchema.Property] = properties.map { property in
            switch property.type {
            case .string:
                return DynamicGenerationSchema.Property(
                    name: property.name,
                    description: nil,
                    schema: DynamicGenerationSchema(type: String.self)
                )
            case .int:
                return DynamicGenerationSchema.Property(
                    name: property.name,
                    description: nil,
                    schema: DynamicGenerationSchema(type: Int.self)
                )
            case .boolean:
                return DynamicGenerationSchema.Property(
                    name: property.name,
                    description: nil,
                    schema: DynamicGenerationSchema(type: Bool.self)
                )
            case .number:
                return DynamicGenerationSchema.Property(
                    name: property.name,
                    description: nil,
                    schema: DynamicGenerationSchema(type: Double.self)
                )
            }
        }

        let root = DynamicGenerationSchema(
            name: name,
            description: nil,
            properties: dynamicProperties
        )
        do {
            return try GenerationSchema(root: root, dependencies: [])
        } catch {
            throw FMXError.schemaBuildFailed(error.localizedDescription)
        }
    }
}

struct SchemaPropertyDefinition: Codable {
    enum PropertyType: String, Codable {
        case string
        case int
        case boolean
        case number
    }

    var name: String
    var type: PropertyType
}
