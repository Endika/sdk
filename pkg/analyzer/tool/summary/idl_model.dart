// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This file contains a set of concrete classes representing an in-memory
 * semantic model of the IDL used to code generate summary serialization and
 * deserialization code.
 */
library analyzer.tool.summary.idl_model;

/**
 * Information about a single class defined in the IDL.
 */
class ClassDeclaration extends Declaration {
  /**
   * Fields defined in the class.
   */
  final List<FieldDeclaration> fields = <FieldDeclaration>[];

  /**
   * Indicates whether the class has the `topLevel` annotation.
   */
  final bool isTopLevel;

  ClassDeclaration(String documentation, String name, this.isTopLevel)
      : super(documentation, name);
}

/**
 * Information about a declaration in the IDL.
 */
class Declaration {
  /**
   * The optional documentation, may be `null`.
   */
  final String documentation;

  /**
   * The name of the declaration.
   */
  final String name;

  Declaration(this.documentation, this.name);
}

/**
 * Information about a single enum defined in the IDL.
 */
class EnumDeclaration extends Declaration {
  /**
   * List of enumerated values.
   */
  final List<String> values = <String>[];

  EnumDeclaration(String documentation, String name)
      : super(documentation, name);
}

/**
 * Information about a single class field defined in the IDL.
 */
class FieldDeclaration extends Declaration {
  /**
   * The file of the field.
   */
  final FieldType type;

  FieldDeclaration(String documentation, String name, this.type)
      : super(documentation, name);
}

/**
 * Information about the type of a class field defined in the IDL.
 */
class FieldType {
  /**
   * Type of the field (e.g. 'int').
   */
  final String typeName;

  /**
   * Indicates whether this field contains a list of the type specified in
   * [typeName].
   */
  final bool isList;

  FieldType(this.typeName, this.isList);
}

/**
 * Top level representation of the summary IDL.
 */
class Idl {
  /**
   * Classes defined in the IDL.
   */
  final Map<String, ClassDeclaration> classes = <String, ClassDeclaration>{};

  /**
   * Enums defined in the IDL.
   */
  final Map<String, EnumDeclaration> enums = <String, EnumDeclaration>{};
}
