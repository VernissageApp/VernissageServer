//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CacheableMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax,
                                 providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            throw CacheableError.message("@Cacheable function not found.")
        }
        
         return [DeclSyntax(stringLiteral: """
                func \(function.name.text)Cacheable(request: Request) async throws -> [CountryDto] {
                    let countries = try await Country.query(on: request.db).all()
                    let countriesDtos = countries.map({ CountryDto(from: $0) })
                    return countriesDtos
                 }
                """)]
     }
}

public struct _CacheableMacro: PeerMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax, providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        // Ensure the macro is attached to a function.
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw CacheableError.message("@Cacheable can only be applied to functions.")
        }
        
        // Ensure the function has a body.
        guard let body = funcDecl.body else {
            throw CacheableError.message("@Cacheable function must have a body.")
        }
        
        // Get the function's return type.
        guard let returnType = funcDecl.signature.returnClause?.type.description.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw CacheableError.message("@Cacheable function must have a return type.")
        }
        
        // Helper function to find the enclosing type name.
        func findEnclosingTypeName(from node: Syntax) -> String? {
            var currentNode = node.parent
            while let node = currentNode {
                if let structDecl = node.as(StructDeclSyntax.self) {
                    return structDecl.name.text
                } else if let classDecl = node.as(ClassDeclSyntax.self) {
                    return classDecl.name.text
                } else if let enumDecl = node.as(EnumDeclSyntax.self) {
                    return enumDecl.name.text
                }
                currentNode = node.parent
            }
            return nil
        }
        
        // Upcast funcDecl to Syntax using the Syntax initializer.
        let syntaxNode = Syntax(funcDecl)

        // Get the enclosing type name.
        let enclosingTypeName = findEnclosingTypeName(from: syntaxNode) ?? ""
        
        // Parse macro arguments for custom cache key (if provided).
        var cacheKeyExpression: String
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self), let firstArg = arguments.first {
            cacheKeyExpression = firstArg.expression.description
        } else {
            // Default cache key includes the enclosing type name and function name.
            if enclosingTypeName.isEmpty {
                cacheKeyExpression = "\"\(funcDecl.name.text)\""
            } else {
                cacheKeyExpression = "\"\(enclosingTypeName).\(funcDecl.name.text)\""
            }
        }
        
        // Statements to insert at the beginning.
        let beginningStatements = CodeBlockItemListSyntax {
            CodeBlockItemSyntax(item: .stmt(StmtSyntax("if let cachedValue: \(raw: returnType) = try? await request.cache.get(\(raw: cacheKeyExpression)) {")))
            CodeBlockItemSyntax(item: .stmt(StmtSyntax("    return cachedValue")))
            CodeBlockItemSyntax(item: .stmt(StmtSyntax("\n")))
            CodeBlockItemSyntax(item: .stmt(StmtSyntax("}")))
        }
        
        // Prepare the new statements.
        var newStatements = [CodeBlockItemSyntax]()
        newStatements.append(contentsOf: beginningStatements)
        
        // Original function statements, replacing return statements.
        var hasReturn = false
        for stmt in body.statements {
            if let returnStmt = stmt.item.as(ReturnStmtSyntax.self),
               let expression = returnStmt.expression {
                newStatements.append(CodeBlockItemSyntax(item: .decl(DeclSyntax("let result = \(expression)"))))
                hasReturn = true
            } else {
                newStatements.append(stmt)
            }
        }
        
        if !hasReturn {
            throw CacheableError.message("@Cacheable function must have a return statement.")
        }
        
        // Insert cache set statement.
        newStatements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax("\n"))))
        newStatements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax("try? await request.cache.set(\(raw: cacheKeyExpression), to: result, expiresIn: .minutes(60))"))))

        // Return the result.
        newStatements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax("return result"))))
        
        // Create the new function body.
        let newBody = CodeBlockSyntax(
            leftBrace: body.leftBrace,
            statements: CodeBlockItemListSyntax(newStatements),
            rightBrace: body.rightBrace
        )
        
        // Create a new FunctionDeclSyntax with the updated body.
        let newFuncDecl = FunctionDeclSyntax(
            attributes: funcDecl.attributes,
            modifiers: funcDecl.modifiers,
            funcKeyword: funcDecl.funcKeyword,
            name: funcDecl.name,
            genericParameterClause: funcDecl.genericParameterClause,
            signature: funcDecl.signature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: newBody
        )
        
        return [DeclSyntax(newFuncDecl)]
    }
    
    /*
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        // Ensure the macro is attached to a function.
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw CacheableError.message("@Cacheable can only be applied to functions.")
        }
        
        // Ensure the function has a body.
        guard let body = funcDecl.body else {
            throw CacheableError.message("@Cacheable function must have a body.")
        }
        
        // Get the function's return type.
        guard let returnType = funcDecl.signature.returnClause?.type.description.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw CacheableError.message("@Cacheable function must have a return type.")
        }
        
        // Helper function to find the enclosing type name.
        func findEnclosingTypeName(from node: Syntax) -> String? {
            var currentNode = node.parent
            while let node = currentNode {
                if let structDecl = node.as(StructDeclSyntax.self) {
                    return structDecl.name.text
                } else if let classDecl = node.as(ClassDeclSyntax.self) {
                    return classDecl.name.text
                } else if let enumDecl = node.as(EnumDeclSyntax.self) {
                    return enumDecl.name.text
                }
                currentNode = node.parent
            }
            return nil
        }
        
        // Upcast funcDecl to Syntax using the Syntax initializer.
        let syntaxNode = Syntax(funcDecl)

        // Get the enclosing type name.
        let enclosingTypeName = findEnclosingTypeName(from: syntaxNode) ?? ""
        
        // Parse macro arguments for custom cache key (if provided).
        var cacheKeyExpression: String
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self), let firstArg = arguments.first {
            cacheKeyExpression = firstArg.expression.description
        } else {
            // Default cache key includes the enclosing type name and function name.
            if enclosingTypeName.isEmpty {
                cacheKeyExpression = "\"\(funcDecl.name.text)\""
            } else {
                cacheKeyExpression = "\"\(enclosingTypeName).\(funcDecl.name.text)\""
            }
        }
        
        // Statements to insert at the beginning.
        let beginningStatements = CodeBlockItemListSyntax {
            CodeBlockItemSyntax(item: .stmt(StmtSyntax("if let cachedValue: \(raw: returnType) = try? await request.cache.get(\(raw: cacheKeyExpression)) {")))
            CodeBlockItemSyntax(item: .stmt(StmtSyntax("    return cachedValue")))
            CodeBlockItemSyntax(item: .stmt(StmtSyntax("}")))
        }
        
        // Prepare the new statements.
        var newStatements = [CodeBlockItemSyntax]()
        newStatements.append(contentsOf: beginningStatements)
        
        // Original function statements, replacing return statements.
        var hasReturn = false
        for stmt in body.statements {
            if let returnStmt = stmt.item.as(ReturnStmtSyntax.self),
               let expression = returnStmt.expression {
                newStatements.append(CodeBlockItemSyntax(item: .decl(DeclSyntax("let result = \(expression)"))))
                hasReturn = true
            } else {
                newStatements.append(stmt)
            }
        }
        
        if !hasReturn {
            throw CacheableError.message("@Cacheable function must have a return statement.")
        }
        
        // Insert cache set statement.
        newStatements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax("try? await request.cache.set(\(raw: cacheKeyExpression), to: result, expiresIn: .minutes(60))"))))

        // Return the result.
        newStatements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax("return result"))))
        
        // Create the new function body.
        let newBody = CodeBlockSyntax(
            leftBrace: body.leftBrace,
            statements: CodeBlockItemListSyntax(newStatements),
            rightBrace: body.rightBrace
        )
        
        // Create a new FunctionDeclSyntax with the updated body.
        let newFuncDecl = FunctionDeclSyntax(
            attributes: funcDecl.attributes,
            modifiers: funcDecl.modifiers,
            funcKeyword: funcDecl.funcKeyword,
            name: funcDecl.name,
            genericParameterClause: funcDecl.genericParameterClause,
            signature: funcDecl.signature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: newBody
        )
        
        return DeclSyntax(newFuncDecl)
    }
     */
}
