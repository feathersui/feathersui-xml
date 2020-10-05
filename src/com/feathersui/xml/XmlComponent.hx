/*
	XML Components for Feathers UI
	Copyright 2020 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package com.feathersui.xml;

import haxe.xml.Parser.XmlParserException;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
#if macro
import sys.io.File;
import sys.FileSystem;
#end

/**
	Creates Haxe classes and instances at compile-time using XML.
**/
class XmlComponent {
	#if macro
	private static final FILE_PATH_TO_TYPE_DEFINITION:Map<String, TypeDefinition> = [];
	private static final PROPERTY_ID = "id";
	private static final PROPERTY_XMLNS = "xmlns";
	private static final PROPERTY_XMLNS_PREFIX = "xmlns:";
	private static final RESERVED_PROPERTIES = [PROPERTY_ID, PROPERTY_XMLNS];
	private static var componentCounter = 0;
	private static var objectCounter = 0;

	private static final URI_HAXE = "http://ns.haxe.org/4/xml";
	private static final MAPPINGS_HAXE = [
		"Float" => "Float",
		"Int" => "Int",
		"UInt" => "UInt",
		"Bool" => "Bool",
		"String" => "String",
		"Dynamic" => "Dynamic",
		"Array" => "Array"
	];
	private static var uriToMappings:Map<String, Map<String, String>> = [URI_HAXE => MAPPINGS_HAXE];

	/**
		Adds a custom mapping from a namespace URI to a list of components in
		the namespace.
	**/
	public static function addNamespaceMapping(uri:String, mappings:Map<String, String>):Void {
		if (!uriToMappings.exists(uri)) {
			uriToMappings.set(uri, mappings);
		} else {
			var existingMappings = uriToMappings.get(uri);
			for (shortName => qualifiedName in mappings) {
				existingMappings.set(shortName, qualifiedName);
			}
		}
	}
	#end

	/**
		Populates fields in a class using markup in a file. Similar to
		`withFile()`, but it's a build macro instead — which gives developers
		more control over the generated class. For instance, it's possible to
		define additional fields and methods to the class, and to instantiate it
		on demand.
	**/
	public macro static function buildWithFile(filePath:String):Array<Field> {
		var xml = loadXmlFile(filePath);
		var firstElement = xml.firstElement();
		if (firstElement == null) {
			Context.fatalError('No root tag found in XML', Context.currentPos());
		}

		var componentTypeName = getComponentType(getXmlName(firstElement), getLocalPrefixMap(firstElement));
		var localClass = Context.getLocalClass().get();
		var superClass = localClass.superClass;
		if (superClass == null || Std.string(superClass.t) != componentTypeName) {
			Context.fatalError('Class ${localClass.name} must extend ${componentTypeName}', Context.currentPos());
		}

		var buildFields = Context.getBuildFields();
		parseRootElement(firstElement, "XMLComponent_initXML", buildFields);
		return buildFields;
	}

	/**
		Instantiates a component from a file containing markup.

		Calling `withFile()` multiple times will re-use the same generated
		class each time.
	**/
	public macro static function withFile(filePath:String):Expr {
		filePath = resolveAsset(filePath);
		var typeDef:TypeDefinition = null;
		if (FILE_PATH_TO_TYPE_DEFINITION.exists(filePath)) {
			// for duplicate files, re-use the existing type definition
			typeDef = FILE_PATH_TO_TYPE_DEFINITION.get(filePath);
		}
		if (typeDef == null) {
			var xml = loadXmlFile(filePath);
			var nameSuffix = Path.withoutExtension(Path.withoutDirectory(filePath));
			typeDef = createTypeDefinitionFromXml(xml, nameSuffix);
			FILE_PATH_TO_TYPE_DEFINITION.set(filePath, typeDef);
		}
		var typePath = {name: typeDef.name, pack: typeDef.pack};
		return macro new $typePath();
	}

	/**
		Instantiates a component from markup.
	**/
	public macro static function withMarkup(input:ExprOf<String>):Expr {
		var xmlString:String = null;
		switch (input.expr) {
			case EMeta({name: ":markup"}, {expr: EConst(CString(s))}):
				xmlString = s;
			case EConst(CString(s)):
				xmlString = s;
			case _:
				throw new haxe.macro.Expr.Error("Expected markup or string literal", input.pos);
		}
		var xml = loadXmlString(xmlString);
		var typeDef = createTypeDefinitionFromXml(xml, "Xml");
		var typePath = {name: typeDef.name, pack: typeDef.pack};
		return macro new $typePath();
	}

	#if macro
	private static function resolveAsset(filePath:String):String {
		if (Path.isAbsolute(filePath)) {
			return filePath;
		}
		var modulePath = Context.getPosInfos(Context.currentPos()).file;
		if (!Path.isAbsolute(modulePath)) {
			modulePath = FileSystem.absolutePath(modulePath);
		}
		modulePath = Path.directory(modulePath);
		return Path.join([modulePath, filePath]);
	}

	private static function loadXmlFile(filePath:String):Xml {
		filePath = resolveAsset(filePath);
		if (!FileSystem.exists(filePath)) {
			Context.fatalError('Component XML file not found: ${filePath}', Context.currentPos());
		}
		var content = File.getContent(filePath);
		return loadXmlString(content);
	}

	private static function loadXmlString(xmlString:String):Xml {
		try {
			return Xml.parse(xmlString);
		} catch (e:XmlParserException) {
			Context.fatalError('XML parse error (${e.lineNumber}, ${e.positionAtLine}): ${e.message}', Context.currentPos());
		}
		return null;
	}

	private static function createTypeDefinitionFromXml(root:Xml, nameSuffix:String):TypeDefinition {
		var firstElement = root.firstElement();
		if (firstElement == null) {
			Context.fatalError('No root tag found in XML', Context.currentPos());
		}
		var buildFields:Array<Field> = [];
		var classType = parseRootElement(firstElement, "XMLComponent_initXML", buildFields);
		var componentName = 'FeathersUI_XMLComponent_${nameSuffix}_${componentCounter}';
		componentCounter++;
		var typeDef:TypeDefinition = null;
		if (classType == null) {
			typeDef = macro class $componentName {};
		} else {
			var superClassTypePath = {name: classType.name, pack: classType.pack};
			typeDef = macro class $componentName extends $superClassTypePath {};
		}
		for (buildField in buildFields) {
			typeDef.fields.push(buildField);
		}
		Context.defineType(typeDef);
		return typeDef;
	}

	private static function parseRootElement(element:Xml, overrideName:String, buildFields:Array<Field>):ClassType {
		objectCounter = 0;
		var localPrefixMap = getLocalPrefixMap(element);
		var xmlName = getXmlName(element);
		var classType = getClassType(xmlName, localPrefixMap);
		var generatedFields:Array<Field> = [];
		var bodyExprs:Array<Expr> = [];
		parseAttributes(element, classType, "this", localPrefixMap, bodyExprs);
		parseChildrenOfObject(element, classType, "this", xmlName.prefix, localPrefixMap, generatedFields, bodyExprs);
		buildFields.push({
			name: overrideName,
			pos: Context.currentPos(),
			kind: FFun({
				args: [],
				ret: macro:Void,
				expr: macro $b{bodyExprs}
			}),
			access: [APrivate],
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			]
		});
		var constructorExprs:Array<Expr> = [macro this.XMLComponent_initXML()];
		if (classType != null) {
			constructorExprs.unshift(macro super());
		}
		buildFields.push({
			name: "new",
			pos: Context.currentPos(),
			kind: FFun({
				args: [],
				ret: macro:Void,
				expr: macro $b{constructorExprs}
			}),
			access: [APublic]
		});
		for (field in generatedFields) {
			buildFields.push(field);
		}
		return classType;
	}

	private static function findField(type:ClassType, fieldName:String):ClassField {
		for (field in getAllFields(type)) {
			if (field.name == fieldName) {
				return field;
			}
		}
		return null;
	}

	private static function findEvent(type:ClassType, eventName:String):MetadataEntry {
		for (eventMeta in getAllEvents(type)) {
			var otherEventName = getEventName(eventMeta);
			if (otherEventName == eventName) {
				return eventMeta;
			}
		}
		return null;
	}

	private static function getEventName(eventMeta:MetadataEntry):String {
		var typedExprDef = Context.typeExpr(eventMeta.params[0]).expr;
		return switch (typedExprDef) {
			case TCast(e, m):
				switch (e.expr) {
					case TConst(c):
						switch (c) {
							case TString(s): s;
							default: null;
						}
					default: null;
				}
			default: null;
		};
	}

	private static function parseChildrenOfObject(element:Xml, parentType:ClassType, targetIdentifier:String, parentPrefix:String,
			prefixMap:Map<String, String>, parentFields:Array<Field>, initExprs:Array<Expr>):Void {
		var defaultChildren:Array<Xml> = null;
		var hasDefaultProperty = parentType == null || parentType.meta.has("defaultXmlProperty");
		for (child in element.iterator()) {
			switch (child.nodeType) {
				case Element:
					var childXmlName = getXmlName(child);
					if (isXmlLanguageElement("Binding", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Component", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Declarations", childXmlName, prefixMap)) {
						if (targetIdentifier == "this") {
							parseDeclarations(child, prefixMap, parentFields, initExprs);
						} else {
							Context.fatalError('The \'<${child.nodeName}>\' tag must be a child of the root element', Context.currentPos());
						}
						continue;
					} else if (isXmlLanguageElement("Definition", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("DesignLayer", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Library", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Metadata", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Model", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Private", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Reparent", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Script", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					} else if (isXmlLanguageElement("Style", childXmlName, prefixMap)) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is not supported', Context.currentPos());
					}
					var foundField:ClassField = null;
					if (childXmlName.prefix == parentPrefix) {
						var localName = childXmlName.localName;
						foundField = findField(parentType, localName);
					}
					if (foundField == null && parentType != null) {
						if (!hasDefaultProperty) {
							Context.fatalError('The \'<${child.nodeName}>\' tag is unexpected', Context.currentPos());
						}
						if (defaultChildren == null) {
							defaultChildren = [];
						}
						defaultChildren.push(child);
						continue;
					}

					var fieldType = foundField != null ? foundField.type : null;
					parseChildrenForField(child.iterator(), targetIdentifier, foundField, childXmlName.localName, fieldType, prefixMap, parentFields,
						initExprs);
				case PCData:
					var str = StringTools.trim(child.nodeValue);
					if (str.length == 0) {
						continue;
					}
					if (!hasDefaultProperty) {
						Context.fatalError('The \'${child.nodeValue}\' value is unexpected', Context.currentPos());
					}
					if (defaultChildren == null) {
						defaultChildren = [];
					}
					defaultChildren.push(child);
				case CData:
					if (!hasDefaultProperty) {
						Context.fatalError('The \'${child.nodeValue}\' value is unexpected', Context.currentPos());
					}
					if (defaultChildren == null) {
						defaultChildren = [];
					}
					defaultChildren.push(child);
				default:
			}
		}

		if (defaultChildren == null) {
			return;
		}

		if (parentType.name == "Array" && parentType.pack.length == 0) {
			parseChildrenForField(defaultChildren.iterator(), targetIdentifier, null, null, Context.getType(parentType.name), prefixMap, parentFields,
				initExprs);
			return;
		}

		var defaultXmlPropMeta = parentType.meta.extract("defaultXmlProperty")[0];
		if (defaultXmlPropMeta.params.length != 1) {
			Context.fatalError('The defaultXmlProperty meta must have one property name', defaultXmlPropMeta.pos);
		}
		var param = defaultXmlPropMeta.params[0];
		var propertyName:String = null;
		switch (param.expr) {
			case EConst(c):
				switch (c) {
					case CString(s, kind):
						propertyName = s;
					default:
				}
			default:
		}
		if (propertyName == null) {
			Context.fatalError('The defaultXmlProperty meta param must be a string', param.pos);
		}
		var defaultField = findField(parentType, propertyName);
		if (defaultField == null) {
			// the metadata is there, but it seems to be referencing a property
			// that doesn't exist
			Context.fatalError('Invalid default property \'${propertyName}\' for the \'<${element.nodeName}>\' tag', Context.currentPos());
		}
		var xmlName = getXmlName(element);

		parseChildrenForField(defaultChildren.iterator(), targetIdentifier, defaultField, defaultField.name, defaultField.type, prefixMap, parentFields,
			initExprs);
	}

	private static function parseDeclarations(element:Xml, prefixMap:Map<String, String>, parentFields:Array<Field>, initExprs:Array<Expr>):Void {
		for (child in element.iterator()) {
			switch (child.nodeType) {
				case Element:
					var childXmlName = getXmlName(child);
					var objectID = child.get(PROPERTY_ID);
					var initExpr:Expr = null;
					if (isBuiltIn(childXmlName, prefixMap) && childXmlName.localName != "Dynamic" && childXmlName.localName != "Array") {
						// TODO: parse attributes too
						for (grandChild in child.iterator()) {
							var str = StringTools.trim(grandChild.nodeValue);
							initExpr = createValueExprForDynamic(str);
							var complexType = Context.toComplexType(Context.typeExpr(initExpr).t);
							if (objectID != null) {
								parentFields.push({
									name: objectID,
									pos: Context.currentPos(),
									kind: FVar(complexType),
									access: [APublic]
								});
							}
						}
					} else {
						var functionName:String = parseChildElement(child, prefixMap, parentFields);
						initExpr = macro $i{functionName}();
					}
					if (objectID != null) {
						initExpr = macro this.$objectID = $initExpr;
					}
					initExprs.push(initExpr);
				case PCData:
					var str = StringTools.trim(child.nodeValue);
					if (str.length == 0) {
						continue;
					}
					Context.fatalError('The \'${child.nodeValue}\' value is unexpected', Context.currentPos());
				default:
					Context.fatalError('Cannot parse XML child \'${child.nodeValue}\' of type \'${child.nodeType}\'', Context.currentPos());
			}
		}
	}

	private static function parseChildrenForField(children:Iterator<Xml>, targetIdentifier:String, field:ClassField, fieldName:String,
			fieldType:haxe.macro.Type, parentPrefixMap:Map<String, String>, parentFields:Array<Field>, initExprs:Array<Expr>):Void {
		var isArray = false;
		while (fieldType != null) {
			switch (fieldType) {
				case TInst(t, params):
					isArray = t.get().name == "Array";
					fieldType = null;
				case TLazy(f):
					fieldType = f();
				default:
					fieldType = null;
			}
		}
		var valueExprs:Array<Expr> = [];
		var firstChildIsArray = false;
		for (child in children) {
			switch (child.nodeType) {
				case Element:
					if (!isArray && valueExprs.length > 0) {
						Context.fatalError('The \'<${child.nodeName}>\' tag is unexpected', Context.currentPos());
					}
					var childXmlName = getXmlName(child);
					if (isBuiltIn(childXmlName, parentPrefixMap)
						&& childXmlName.localName != "Dynamic"
						&& childXmlName.localName != "Array") {
						// TODO: parse attributes too
						for (grandChild in child.iterator()) {
							if (!isArray && valueExprs.length > 0) {
								Context.fatalError('The child of type \'${grandChild.nodeType}\' is unexpected', Context.currentPos());
							}
							var str = StringTools.trim(grandChild.nodeValue);
							if (isArray) {
								var exprType = Context.getType(childXmlName.localName);
								var valueExpr = createValueExprForType(exprType, str);
								valueExprs.push(valueExpr);
							} else if (field == null) {
								var valueExpr = createValueExprForDynamic(str);
								valueExprs.push(valueExpr);
							} else {
								var valueExpr = createValueExprForField(field, str);
								valueExprs.push(valueExpr);
							}
						}
					} else {
						if (valueExprs.length == 0 && childXmlName.localName == "Array") {
							firstChildIsArray = true;
						}
						var functionName:String = parseChildElement(child, parentPrefixMap, parentFields);
						var valueExpr = macro $i{functionName}();
						valueExprs.push(valueExpr);
					}
				case PCData:
					var str = StringTools.trim(child.nodeValue);
					if (str.length == 0) {
						// skip any children that are entirely whitespace
						continue;
					}
					if (!isArray && valueExprs.length > 0) {
						Context.fatalError('The child of type \'${child.nodeType}\' is unexpected', Context.currentPos());
					}
					if (field == null) {
						var valueExpr = createValueExprForDynamic(str);
						valueExprs.push(valueExpr);
					} else {
						var valueExpr = createValueExprForField(field, str);
						valueExprs.push(valueExpr);
					}
				case CData:
					if (!isArray && valueExprs.length > 0) {
						Context.fatalError('The child of type \'${child.nodeType}\' is unexpected', Context.currentPos());
					}
					var str = child.nodeValue;
					if (field == null) {
						var valueExpr = createValueExprForDynamic(str);
						valueExprs.push(valueExpr);
					} else {
						var valueExpr = createValueExprForField(field, str);
						valueExprs.push(valueExpr);
					}
				default:
					Context.fatalError('Cannot parse XML child \'${child.nodeValue}\' of type \'${child.nodeType}\'', Context.currentPos());
			}
		}

		if (valueExprs.length == 0) {
			Context.fatalError('Value for field \'${fieldName}\' must not be empty', Context.currentPos());
		}
		if (!isArray) {
			var valueExpr = valueExprs[0];
			var setExpr = macro $i{targetIdentifier}.$fieldName = ${valueExpr};

			initExprs.push(setExpr);
			return;
		}
		if (isArray && fieldName == null) {
			for (i in 0...valueExprs.length) {
				var valueExpr = valueExprs[i];
				initExprs.push(macro $i{targetIdentifier}[$v{i}] = ${valueExpr});
			}
		} else if (isArray && fieldName != null && valueExprs.length == 1 && firstChildIsArray) {
			var valueExpr = valueExprs[0];
			initExprs.push(macro $i{targetIdentifier}.$fieldName = ${valueExpr});
		} else {
			var localVarName = "array_" + fieldName;
			initExprs.push(macro var $localVarName:Array<Dynamic> = []);
			for (i in 0...valueExprs.length) {
				var valueExpr = valueExprs[i];
				initExprs.push(macro $i{localVarName}[$v{i}] = ${valueExpr});
			}
			initExprs.push(macro $i{targetIdentifier}.$fieldName = cast($i{localVarName}));
		}
	}

	private static function parseChildElement(element:Xml, parentPrefixMap:Map<String, String>, parentFields:Array<Field>):String {
		var localPrefixMap = getLocalPrefixMap(element, parentPrefixMap);
		var xmlName = getXmlName(element);
		var classType = getClassType(xmlName, localPrefixMap);

		var localVarName = "object";
		var childTypePath:TypePath = null;
		if (classType == null) {
			childTypePath = {name: "Dynamic", pack: []};
		} else {
			childTypePath = {name: classType.name, pack: classType.pack};
		}
		var returnTypePath = childTypePath;
		if (classType != null && classType.params.length > 0) {
			returnTypePath = {name: "Dynamic", pack: []}
		}
		var objectID:String = element.get(PROPERTY_ID);
		var setIDExpr:Expr = null;

		if (objectID != null) {
			parentFields.push({
				name: objectID,
				pos: Context.currentPos(),
				kind: FVar(TPath(childTypePath)),
				access: [APublic]
			});
			setIDExpr = macro this.$objectID = $i{localVarName};
		} else {
			objectID = Std.string(objectCounter);
			objectCounter++;
		}

		var setFieldExprs:Array<Expr> = [];
		parseAttributes(element, classType, localVarName, localPrefixMap, setFieldExprs);
		parseChildrenOfObject(element, classType, localVarName, xmlName.prefix, localPrefixMap, parentFields, setFieldExprs);
		if (setIDExpr != null) {
			setFieldExprs.push(setIDExpr);
		}
		var bodyExpr:Expr = null;
		if (classType == null) {
			bodyExpr = macro {
				var $localVarName:Dynamic = {};
				$b{setFieldExprs};
				return $i{localVarName};
			}
		} else {
			bodyExpr = macro {
				var $localVarName = new $childTypePath();
				$b{setFieldExprs};
				return $i{localVarName};
			}
		}
		var functionName = "createXmlObject_" + objectID;
		parentFields.push({
			name: functionName,
			pos: Context.currentPos(),
			kind: FFun({
				args: [],
				ret: TPath(returnTypePath),
				expr: bodyExpr
			}),
			access: [APrivate],
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			]
		});

		return functionName;
	}

	private static function getAllFields(type:ClassType):Array<ClassField> {
		if (type == null) {
			return [];
		}
		var fields = type.fields.get();
		var superClass = type.superClass;
		if (superClass != null) {
			for (field in getAllFields(superClass.t.get())) {
				fields.push(field);
			}
		}
		return fields;
	}

	private static function getAllEvents(type:ClassType):Array<MetadataEntry> {
		if (type == null) {
			return [];
		}
		var events = type.meta.extract(":event").filter(eventMeta -> eventMeta.params.length == 1);
		var superClass = type.superClass;
		if (superClass != null) {
			for (event in getAllEvents(superClass.t.get())) {
				events.push(event);
			}
		}
		return events;
	}

	private static function parseAttributes(element:Xml, parentType:ClassType, targetIdentifier:String, prefixMap:Map<String, String>,
			initExprs:Array<Expr>):Void {
		for (attribute in element.attributes()) {
			var foundField:ClassField = findField(parentType, attribute);
			if (foundField != null) {
				var fieldValue = element.get(attribute);
				var valueExpr = createValueExprForField(foundField, fieldValue);
				var setExpr = macro $i{targetIdentifier}.$attribute = ${valueExpr};
				initExprs.push(setExpr);
			} else if (parentType == null) {
				var fieldValue = element.get(attribute);
				var valueExpr = createValueExprForDynamic(fieldValue);
				var setExpr = macro $i{targetIdentifier}.$attribute = ${valueExpr};
				initExprs.push(setExpr);
			} else {
				var foundEvent = findEvent(parentType, attribute);
				if (foundEvent != null) {
					var eventName = getEventName(foundEvent);
					var eventText = element.get(attribute);
					var eventExpr = Context.parse(eventText, Context.currentPos());
					var addEventExpr = macro $i{targetIdentifier}.addEventListener($v{eventName}, (event) -> ${eventExpr});
					initExprs.push(addEventExpr);
				} else if (RESERVED_PROPERTIES.indexOf(attribute) == -1 && !StringTools.startsWith(attribute, PROPERTY_XMLNS_PREFIX)) {
					Context.fatalError('Unknown field \'${attribute}\'', Context.currentPos());
				}
			}
		}
	}

	private static function createValueExprForField(field:ClassField, value:String):Expr {
		var fieldName = field.name;
		if (!field.isPublic) {
			Context.fatalError('Cannot set field \'${fieldName}\' because it is not public', Context.currentPos());
		}
		if (value.length == 0) {
			Context.fatalError('The attribute \'${fieldName}\' cannot be empty', Context.currentPos());
		}
		switch (field.kind) {
			case FVar(read, write):
			default:
				Context.fatalError('Cannot set field \'${fieldName}\'', Context.currentPos());
		}
		return createValueExprForType(field.type, value);
	}

	private static function createValueExprForType(fieldType:haxe.macro.Type, value:String):Expr {
		var fieldTypeName:String = null;
		while (fieldTypeName == null) {
			switch (fieldType) {
				case TInst(t, params):
					fieldTypeName = t.get().name;
					break;
				case TAbstract(t, params):
					var abstractType = t.get();
					if (abstractType.name == "Null") {
						fieldType = params[0];
					} else {
						fieldTypeName = abstractType.name;
						break;
					}
				case TEnum(t, params):
					var enumType = t.get();
					fieldTypeName = enumType.name;
					if (enumType.names.indexOf(value) != -1) {
						return macro $i{value};
					}
					break;
				case TLazy(f):
					fieldType = f();
				default:
					Context.fatalError('Cannot parse a value of type \'${fieldTypeName}\' from \'${value}\'', Context.currentPos());
			}
		}
		switch (fieldTypeName) {
			case "Bool":
				if (~/^true|false$/.match(value)) {
					var boolValue = value == "true";
					return macro $v{boolValue};
				}
			case "Float":
				if (~/^-?[0-9]+(\.[0-9]+)?$/.match(value)) {
					var floatValue = Std.parseFloat(value);
					return macro $v{floatValue};
				}
			case "Int":
				var intValue = Std.parseInt(value);
				if (intValue != null) {
					return macro $v{intValue};
				}
			case "UInt":
				var uintValue = Std.parseInt(value);
				if (uintValue != null) {
					return macro $v{uintValue};
				}
			case "String":
				return macro $v{value};
			default:
		}
		Context.fatalError('Cannot parse a value of type \'${fieldTypeName}\' from \'${value}\'', Context.currentPos());
		return null;
	}

	private static function createValueExprForDynamic(value:String):Expr {
		if (~/^true|false$/.match(value)) {
			var boolValue = value == "true";
			return macro $v{boolValue};
		}
		if (~/^-?[0-9]+(\.[0-9]+)?$/.match(value)) {
			var floatValue = Std.parseFloat(value);
			return macro $v{floatValue};
		}
		if (~/^-?[0-9]+?$/.match(value)) {
			var intValue = Std.parseInt(value);
			return macro $v{intValue};
		}
		// it can always be parsed as a string
		return macro $v{value};
	}

	private static function getClassType(xmlName:XmlName, prefixMap:Map<String, String>):ClassType {
		var componentTypeName = getComponentType(xmlName, prefixMap);
		if (componentTypeName == null) {
			Context.fatalError('Class not found for \'<${xmlName.prefix}:${xmlName.localName}>\' tag', Context.currentPos());
			return null;
		}
		var componentType:haxe.macro.Type = null;
		try {
			componentType = Context.getType(componentTypeName);
		} catch (e:Dynamic) {
			Context.fatalError('Cannot create object \'<${xmlName.prefix}:${xmlName.localName}>\'\n${e}', Context.currentPos());
		}
		var classType:ClassType = null;
		switch (componentType) {
			case TInst(t, _):
				return t.get();
			case TAbstract(t, params):
				if (t.get().name == "Dynamic") {
					return null;
				}
				Context.fatalError('Cannot create object \'<${xmlName.prefix}:${xmlName.localName}>\'', Context.currentPos());
				return null;
			default:
				Context.fatalError('Cannot create object \'<${xmlName.prefix}:${xmlName.localName}>\'', Context.currentPos());
				return null;
		}
	}

	private static function getLocalPrefixMap(element:Xml, ?parentPrefixMap:Map<String, String>):Map<String, String> {
		var localPrefixMap:Map<String, String> = null;
		if (parentPrefixMap == null) {
			localPrefixMap = [];
		} else {
			localPrefixMap = parentPrefixMap.copy();
		}
		for (attribute in element.attributes()) {
			if (attribute == "xmlns") {
				var uri = element.get(attribute);
				localPrefixMap.set("", uri);
			} else if (StringTools.startsWith(attribute, "xmlns:")) {
				var prefix = attribute.substr(6);
				var uri = element.get(attribute);
				localPrefixMap.set(prefix, uri);
			}
		}
		return localPrefixMap;
	}

	private static function getXmlName(element:Xml):XmlName {
		var nameParts = element.nodeName.split(":");
		if (nameParts.length == 1) {
			return new XmlName("", nameParts[0]);
		} else if (nameParts.length == 2) {
			var prefix = nameParts[0];
			var localName = nameParts[1];
			return new XmlName(prefix, localName);
		}
		Context.fatalError('Invalid element name \'<${element.nodeName}>\'', Context.currentPos());
		return null;
	}

	private static function getComponentType(xmlName:XmlName, prefixMap:Map<String, String>):String {
		var prefix = xmlName.prefix;
		if (!prefixMap.exists(prefix)) {
			Context.fatalError('Unknown XML namespace prefix \'${prefix}\'', Context.currentPos());
		}
		var uri = prefixMap.get(prefix);
		var localName = xmlName.localName;
		if (uri != null && uriToMappings.exists(uri)) {
			var mappings = uriToMappings.get(uri);
			if (mappings.exists(localName)) {
				return mappings.get(localName);
			}
		}
		if (uri != null && StringTools.endsWith(uri, ".*")) {
			return uri.substr(0, uri.length - 1) + localName;
		}
		return null;
	}

	private static function isBuiltIn(xmlName:XmlName, prefixMap:Map<String, String>):Bool {
		var prefix = xmlName.prefix;
		if (!prefixMap.exists(prefix)) {
			Context.fatalError('Unknown XML namespace prefix \'${prefix}\'', Context.currentPos());
		}
		var uri = prefixMap.get(prefix);
		var localName = xmlName.localName;
		if (uri == URI_HAXE && MAPPINGS_HAXE.exists(localName)) {
			return true;
		}
		return false;
	}

	private static function isXmlLanguageElement(elementName:String, xmlName:XmlName, prefixMap:Map<String, String>):Bool {
		var prefix = xmlName.prefix;
		if (!prefixMap.exists(prefix)) {
			Context.fatalError('Unknown XML namespace prefix \'${prefix}\'', Context.currentPos());
		}
		return xmlName.localName == elementName && prefixMap.get(prefix) == URI_HAXE;
	}
	#end
}

private class XmlName {
	public function new(prefix:String, localName:String) {
		this.prefix = prefix;
		this.localName = localName;
	}

	public var prefix:String;
	public var localName:String;
}
