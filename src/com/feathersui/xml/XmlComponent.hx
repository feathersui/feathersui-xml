/*
	XML Components for Feathers UI
	Copyright 2021 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package com.feathersui.xml;

#if macro
import com.feathersui.xml.Xml176Parser;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.PositionTools;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import haxe.xml.Parser.XmlParserException;
import sys.FileSystem;
import sys.io.File;
#end

/**
	Creates Haxe classes and instances at compile-time using XML. The
	`XmlComponent` class offers two static methods, `withMarkup()` and
	`withFile()`.

	Pass a markup string to `XmlComponent.withMarkup()` to create a component
	instance from a string.

	```haxe
	var instance = XmlComponent.withMarkup(
		'<f:LayoutGroup xmlns:f="http://ns.feathersui.com/xml">
			<f:layout>
				<f:HorizontalLayout gap="10" horizontalAlign="RIGHT"/>
			</f:layout>
			<f:Button id="okButton" text="OK"/>
			<f:Button id="cancelButton" text="Cancel"/>
		</f:LayoutGroup>'
	);
	container.addChild(instance);
	container.okButton.addEventListener(TriggerEvent.TRIGGER, (event) -> {
		trace("triggered the OK button");
	});
	```

	Pass a file path (relative to the current _.hx_ source file) to
	`XmlComponent.withFile()` to create a component instance from markup saved
	in an external file.

	```haxe
	var instance = XmlComponent.withFile("path/to/file.xml");
	```
**/
@:access("com.feathersui.xml.Xml176Parser")
class XmlComponent {
	#if macro
	private static final FILE_PATH_TO_TYPE_DEFINITION:Map<String, TypeDefinition> = [];
	private static final PROPERTY_ID = "id";
	private static final PROPERTY_XMLNS = "xmlns";
	private static final PROPERTY_XMLNS_PREFIX = "xmlns:";
	private static final RESERVED_PROPERTIES = [PROPERTY_ID, PROPERTY_XMLNS];
	private static var componentCounter = 0;
	private static var objectCounter = 0;
	private static var posInfos:{min:Int, max:Int, file:String};

	private static final URI_HAXE = "http://ns.haxe.org/4/xml";
	private static final MAPPINGS_HAXE = [
		"Float" => "Float",
		"Int" => "Int",
		"UInt" => "UInt",
		"Bool" => "Bool",
		"String" => "String",
		"Dynamic" => "Dynamic",
		"Any" => "Any",
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
		var xmlDocument = loadXmlFile(filePath);
		var xml = xmlDocument.document;
		var firstElement = xml.firstElement();
		if (firstElement == null) {
			Context.error('No root tag found in XML', Context.currentPos());
		}

		var prefixMap = getLocalPrefixMap(firstElement);
		var componentTypeName = getComponentType(getXmlName(firstElement, prefixMap, xmlDocument), prefixMap);
		var localClass = Context.getLocalClass().get();
		var superClass = localClass.superClass;
		if (superClass == null || Std.string(superClass.t) != componentTypeName) {
			Context.error('Class ${localClass.name} must extend ${componentTypeName}', Context.currentPos());
		}

		var buildFields = Context.getBuildFields();
		parseRootElement(firstElement, "XMLComponent_initXML", buildFields, xmlDocument);
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
			var xmlDocument = loadXmlFile(filePath);
			var nameSuffix = Path.withoutExtension(Path.withoutDirectory(filePath));
			typeDef = createTypeDefinitionFromXml(xmlDocument, nameSuffix);
			FILE_PATH_TO_TYPE_DEFINITION.set(filePath, typeDef);
		}
		var typePath = {name: typeDef.name, pack: typeDef.pack};
		return macro new $typePath();
	}

	/**
		Instantiates a component from markup.
	**/
	public macro static function withMarkup(input:ExprOf<String>):Expr {
		posInfos = PositionTools.getInfos(input.pos);
		var xmlString:String = null;
		switch (input.expr) {
			case EMeta({name: ":markup"}, {expr: EConst(CString(s))}):
				xmlString = s;
			case EConst(CString(s)):
				xmlString = s;
			case _:
				throw new haxe.macro.Expr.Error("Expected markup or string literal", input.pos);
		}
		var xmlDocument = loadXmlString(xmlString);
		var typeDef = createTypeDefinitionFromXml(xmlDocument, "Xml");
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

	private static function loadXmlFile(filePath:String):Xml176Document {
		filePath = resolveAsset(filePath);
		if (!FileSystem.exists(filePath)) {
			Context.error('Component XML file not found: ${filePath}', Context.currentPos());
		}
		var content = File.getContent(filePath);
		posInfos = {file: filePath, min: 0, max: content.length};
		return loadXmlString(content);
	}

	private static function loadXmlString(xmlString:String):Xml176Document {
		try {
			return Xml176Parser.parse(xmlString);
		} catch (e:XmlParserException) {
			errorAtXmlPosition('XML parse error: ${e.message}', {from: e.position});
		} catch (e:String) {
			errorAtXmlPosition('XML parse error: ${e}', {from: 0});
		}
		return null;
	}

	private static function xmlPosToPosition(xmlPos:Pos):Position {
		var min = posInfos.min;
		var from = 0;
		var to = 0;
		if (xmlPos != null) {
			from = xmlPos.from;
			to = (xmlPos.to != null) ? xmlPos.to : xmlPos.from;
		}
		return Context.makePosition({file: posInfos.file, min: min + from, max: min + to});
	}

	private static function fatalErrorAtXmlPosition(text:String, xmlPos:Pos):Void {
		var errorPos = xmlPosToPosition(xmlPos);
		Context.fatalError(text, errorPos);
	}

	private static function errorAtXmlPosition(text:String, xmlPos:Pos):Void {
		var errorPos = xmlPosToPosition(xmlPos);
		Context.error(text, errorPos);
	}

	private static function createTypeDefinitionFromXml(xmlDocument:Xml176Document, nameSuffix:String):TypeDefinition {
		var root = xmlDocument.document;
		var firstElement = root.firstElement();
		if (firstElement == null) {
			errorAtXmlPosition('No root tag found in XML', xmlDocument.getNodePosition(root));
		}
		var buildFields:Array<Field> = [];
		var classType = parseRootElement(firstElement, "XMLComponent_initXML", buildFields, xmlDocument);
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

	private static function parseRootElement(element:Xml, overrideName:String, buildFields:Array<Field>, xmlDocument:Xml176Document):ClassType {
		objectCounter = 0;
		var localPrefixMap = getLocalPrefixMap(element);
		var xmlName = getXmlName(element, localPrefixMap, xmlDocument);
		var classType = getClassType(xmlName, localPrefixMap, element, xmlDocument);
		var generatedFields:Array<Field> = [];
		var bodyExprs:Array<Expr> = [];
		parseAttributes(element, classType, "this", localPrefixMap, bodyExprs, xmlDocument);
		parseChildrenOfObject(element, classType, "this", xmlName.prefix, localPrefixMap, generatedFields, bodyExprs, xmlDocument);
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
			prefixMap:Map<String, String>, parentFields:Array<Field>, initExprs:Array<Expr>, xmlDocument:Xml176Document):Void {
		var defaultChildren:Array<Xml> = null;
		var hasDefaultProperty = parentType == null || parentType.meta.has("defaultXmlProperty");
		for (child in element.iterator()) {
			switch (child.nodeType) {
				case Element:
					var childXmlName = getXmlName(child, prefixMap, xmlDocument);
					if (isXmlLanguageElement("Binding", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Component", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Declarations", childXmlName, prefixMap)) {
						if (targetIdentifier == "this") {
							parseDeclarations(child, prefixMap, parentFields, initExprs, xmlDocument);
						} else {
							errorAtXmlPosition('The \'<${child.nodeName}>\' tag must be a child of the root element', xmlDocument.getNodePosition(child));
						}
						continue;
					} else if (isXmlLanguageElement("Definition", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("DesignLayer", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Library", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Metadata", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Model", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Private", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Reparent", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Script", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					} else if (isXmlLanguageElement("Style", childXmlName, prefixMap)) {
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is not supported', xmlDocument.getNodePosition(child));
					}
					var foundField:ClassField = null;
					if (childXmlName.prefix == parentPrefix) {
						var localName = childXmlName.localName;
						foundField = findField(parentType, localName);
					}
					if (foundField == null && parentType != null) {
						var isArray = parentType.name == "Array" && parentType.pack.length == 0;
						if (!hasDefaultProperty && !isArray) {
							errorAtXmlPosition('The \'<${child.nodeName}>\' tag is unexpected', xmlDocument.getNodePosition(child));
						}
						if (defaultChildren == null) {
							defaultChildren = [];
						}
						defaultChildren.push(child);
						continue;
					}

					var fieldType = foundField != null ? foundField.type : null;
					parseChildrenForField(child, child.iterator(), targetIdentifier, foundField, childXmlName.localName, fieldType, prefixMap, parentFields,
						initExprs, xmlDocument);
				case PCData:
					var str = StringTools.trim(child.nodeValue);
					if (str.length == 0) {
						continue;
					}
					if (!hasDefaultProperty) {
						errorAtXmlPosition('The \'${child.nodeValue}\' value is unexpected', xmlDocument.getNodePosition(child));
					}
					if (defaultChildren == null) {
						defaultChildren = [];
					}
					defaultChildren.push(child);
				case CData:
					if (!hasDefaultProperty) {
						errorAtXmlPosition('The \'${child.nodeValue}\' value is unexpected', xmlDocument.getNodePosition(child));
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
			parseChildrenForField(element, defaultChildren.iterator(), targetIdentifier, null, null, Context.getType(parentType.name), prefixMap,
				parentFields, initExprs, xmlDocument);
			return;
		}

		var defaultXmlPropMeta = parentType.meta.extract("defaultXmlProperty")[0];
		if (defaultXmlPropMeta.params.length != 1) {
			Context.error('The defaultXmlProperty meta must have one property name', defaultXmlPropMeta.pos);
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
			Context.error('The defaultXmlProperty meta param must be a string', param.pos);
		}
		var defaultField = findField(parentType, propertyName);
		if (defaultField == null) {
			// the metadata is there, but it seems to be referencing a property
			// that doesn't exist
			Context.error('Invalid default property \'${propertyName}\' for the \'<${element.nodeName}>\' tag', defaultXmlPropMeta.pos);
		}
		var xmlName = getXmlName(element, prefixMap, xmlDocument);

		parseChildrenForField(element, defaultChildren.iterator(), targetIdentifier, defaultField, defaultField.name, defaultField.type, prefixMap,
			parentFields, initExprs, xmlDocument);
	}

	private static function parseDeclarations(element:Xml, prefixMap:Map<String, String>, parentFields:Array<Field>, initExprs:Array<Expr>,
			xmlDocument:Xml176Document):Void {
		for (child in element.iterator()) {
			switch (child.nodeType) {
				case Element:
					var localPrefixMap = getLocalPrefixMap(child, prefixMap);
					var childXmlName = getXmlName(child, localPrefixMap, xmlDocument);
					var objectID = child.get(PROPERTY_ID);
					var initExpr:Expr = null;
					if (isBuiltIn(childXmlName, prefixMap) && childXmlName.localName != "Dynamic" && childXmlName.localName != "Any"
						&& childXmlName.localName != "Array") {
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
						var functionName:String = parseChildElement(child, prefixMap, parentFields, xmlDocument);
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
					errorAtXmlPosition('The \'${child.nodeValue}\' value is unexpected', xmlDocument.getNodePosition(child));
				default:
					errorAtXmlPosition('Cannot parse XML child \'${child.nodeValue}\' of type \'${child.nodeType}\'', xmlDocument.getNodePosition(child));
			}
		}
	}

	private static function parseChildrenForField(parent:Xml, children:Iterator<Xml>, targetIdentifier:String, field:ClassField, fieldName:String,
			fieldType:haxe.macro.Type, parentPrefixMap:Map<String, String>, parentFields:Array<Field>, initExprs:Array<Expr>,
			xmlDocument:Xml176Document):Void {
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
						errorAtXmlPosition('The \'<${child.nodeName}>\' tag is unexpected', xmlDocument.getNodePosition(child));
					}
					var childXmlName = getXmlName(child, parentPrefixMap, xmlDocument);
					if (isBuiltIn(childXmlName, parentPrefixMap)
						&& childXmlName.localName != "Dynamic"
						&& childXmlName.localName != "Any"
						&& childXmlName.localName != "Array") {
						// TODO: parse attributes too
						for (grandChild in child.iterator()) {
							if (!isArray && valueExprs.length > 0) {
								errorAtXmlPosition('The child of type \'${grandChild.nodeType}\' is unexpected', xmlDocument.getNodePosition(child));
							}
							var str = StringTools.trim(grandChild.nodeValue);
							if (isArray) {
								var exprType = Context.getType(childXmlName.localName);
								var valueExpr = createValueExprForType(exprType, str, child, xmlDocument);
								valueExprs.push(valueExpr);
							} else if (field == null) {
								var valueExpr = createValueExprForDynamic(str);
								valueExprs.push(valueExpr);
							} else {
								var valueExpr = createValueExprForField(field, str, child, xmlDocument);
								valueExprs.push(valueExpr);
							}
						}
					} else {
						if (valueExprs.length == 0 && childXmlName.localName == "Array") {
							firstChildIsArray = true;
						}
						var functionName:String = parseChildElement(child, parentPrefixMap, parentFields, xmlDocument);
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
						errorAtXmlPosition('The child of type \'${child.nodeType}\' is unexpected', xmlDocument.getNodePosition(child));
					}
					if (field == null) {
						var valueExpr = createValueExprForDynamic(str);
						valueExprs.push(valueExpr);
					} else {
						var valueExpr = createValueExprForField(field, str, child, xmlDocument);
						valueExprs.push(valueExpr);
					}
				case CData:
					if (!isArray && valueExprs.length > 0) {
						errorAtXmlPosition('The child of type \'${child.nodeType}\' is unexpected', xmlDocument.getNodePosition(child));
					}
					var str = child.nodeValue;
					if (field == null) {
						var valueExpr = createValueExprForDynamic(str);
						valueExprs.push(valueExpr);
					} else {
						var valueExpr = createValueExprForField(field, str, child, xmlDocument);
						valueExprs.push(valueExpr);
					}
				default:
					errorAtXmlPosition('Cannot parse XML child \'${child.nodeValue}\' of type \'${child.nodeType}\'', xmlDocument.getNodePosition(child));
			}
		}

		if (valueExprs.length == 0) {
			errorAtXmlPosition('Value for field \'${fieldName}\' must not be empty', xmlDocument.getNodePosition(parent));
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

	private static function parseChildElement(element:Xml, parentPrefixMap:Map<String, String>, parentFields:Array<Field>, xmlDocument:Xml176Document):String {
		var localPrefixMap = getLocalPrefixMap(element, parentPrefixMap);
		var xmlName = getXmlName(element, localPrefixMap, xmlDocument);
		var classType = getClassType(xmlName, localPrefixMap, element, xmlDocument);

		var localVarName = "object";
		var childTypePath:TypePath = null;
		if (classType == null) {
			childTypePath = {name: xmlName.localName, pack: []};
		} else {
			childTypePath = {name: classType.name, pack: classType.pack};
			if (classType.name == "Array" && classType.pack.length == 0) {
				var paramTypePath:TypePath = {name: "Dynamic", pack: []};
				childTypePath.params = [TPType(TPath(paramTypePath))];
			}
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
		parseAttributes(element, classType, localVarName, localPrefixMap, setFieldExprs, xmlDocument);
		parseChildrenOfObject(element, classType, localVarName, xmlName.prefix, localPrefixMap, parentFields, setFieldExprs, xmlDocument);
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

	private static function parseAttributes(element:Xml, parentType:ClassType, targetIdentifier:String, prefixMap:Map<String, String>, initExprs:Array<Expr>,
			xmlDocument:Xml176Document):Void {
		for (attribute in element.attributes()) {
			if (StringTools.startsWith(attribute, "xmlns:")) {
				continue;
			}
			var foundField:ClassField = findField(parentType, attribute);
			if (foundField == null && attribute == "id") {
				// set id if it's available, otherwise skip it
				continue;
			}
			if (foundField != null) {
				var fieldValue = element.get(attribute);
				var valueExpr = createValueExprForField(foundField, fieldValue, element, xmlDocument);
				var setExpr = macro $i{targetIdentifier}.$attribute = ${valueExpr};
				initExprs.push(setExpr);
			} else if (parentType == null) {
				var fieldValue = element.get(attribute);
				var valueExpr = createValueExprForDynamic(fieldValue);
				var setExpr = macro Reflect.setField($i{targetIdentifier}, $v{attribute}, ${valueExpr});
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
					var attrPos = xmlDocument.getAttrPosition(element, attribute);
					errorAtXmlPosition('Unknown field \'${attribute}\'', attrPos);
				}
			}
		}
	}

	private static function createValueExprForField(field:ClassField, value:String, element:Xml, xmlDocument:Xml176Document):Expr {
		var fieldName = field.name;
		if (!field.isPublic) {
			errorAtXmlPosition('Cannot set field \'${fieldName}\' because it is not public', xmlDocument.getNodePosition(element));
		}
		if (value.length == 0) {
			errorAtXmlPosition('The attribute \'${fieldName}\' cannot be empty', xmlDocument.getNodePosition(element));
		}
		switch (field.kind) {
			case FVar(read, write):
			default:
				errorAtXmlPosition('Cannot set field \'${fieldName}\'', xmlDocument.getNodePosition(element));
		}
		return createValueExprForType(field.type, value, element, xmlDocument);
	}

	private static function createValueExprForType(fieldType:haxe.macro.Type, value:String, element:Xml, xmlDocument:Xml176Document):Expr {
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
					errorAtXmlPosition('Cannot parse a value of type \'${fieldTypeName}\' from \'${value}\'', xmlDocument.getNodePosition(element));
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
		errorAtXmlPosition('Cannot parse a value of type \'${fieldTypeName}\' from \'${value}\'', xmlDocument.getNodePosition(element));
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

	private static function getClassType(xmlName:XmlName, prefixMap:Map<String, String>, element:Xml, xmlDocument:Xml176Document):ClassType {
		var componentTypeName = getComponentType(xmlName, prefixMap);
		if (componentTypeName == null) {
			errorAtXmlPosition('Class not found for \'<${xmlName.prefix}:${xmlName.localName}>\' tag', xmlDocument.getNodePosition(element));
			return null;
		}
		var componentType:haxe.macro.Type = null;
		try {
			componentType = Context.getType(componentTypeName);
		} catch (e:Dynamic) {
			errorAtXmlPosition('Cannot create object \'<${xmlName.prefix}:${xmlName.localName}>\'\n${e}', xmlDocument.getNodePosition(element));
		}
		var classType:ClassType = null;
		switch (componentType) {
			case TInst(t, _):
				return t.get();
			case TAbstract(t, params):
				var abstractType = t.get();
				if (abstractType.name == "Dynamic" && abstractType.pack.length == 0) {
					return null;
				}
				if (abstractType.name == "Any" && abstractType.pack.length == 0) {
					return null;
				}
				errorAtXmlPosition('Cannot create object \'<${xmlName.prefix}:${xmlName.localName}>\'', xmlDocument.getNodePosition(element));
				return null;
			default:
				errorAtXmlPosition('Cannot create object \'<${xmlName.prefix}:${xmlName.localName}>\'', xmlDocument.getNodePosition(element));
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

	private static function getXmlName(element:Xml, prefixMap:Map<String, String>, xmlDocument:Xml176Document):XmlName {
		var nameParts = element.nodeName.split(":");
		if (nameParts.length == 1) {
			return new XmlName("", nameParts[0]);
		} else if (nameParts.length == 2) {
			var prefix = nameParts[0];
			if (!prefixMap.exists(prefix)) {
				errorAtXmlPosition('Unknown XML namespace prefix \'${prefix}\'', xmlDocument.getNodePosition(element));
			}
			var localName = nameParts[1];
			return new XmlName(prefix, localName);
		}
		errorAtXmlPosition('Invalid element name \'<${element.nodeName}>\'', xmlDocument.getNodePosition(element));
		return null;
	}

	private static function getComponentType(xmlName:XmlName, prefixMap:Map<String, String>):String {
		var prefix = xmlName.prefix;
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
		var uri = prefixMap.get(prefix);
		var localName = xmlName.localName;
		if (uri == URI_HAXE && MAPPINGS_HAXE.exists(localName)) {
			return true;
		}
		return false;
	}

	private static function isXmlLanguageElement(elementName:String, xmlName:XmlName, prefixMap:Map<String, String>):Bool {
		var prefix = xmlName.prefix;
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
