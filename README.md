# XML Components for Feathers UI

An **experimental** library containing [Haxe macros](https://haxe.org/manual/macro.html) to create [Feathers UI](https://feathersui.com/) components at compile-time using markup.

This markup is inspired by MXML, which is an XML dialect designed for creating user interfaces with Apache Flex (originally developed at Macromedia and then Adobe).

## Usage

The `XmlComponent` class contains some macro functions, like `withMarkup()` and `withFile()`, that may be used to create custom components from markup.

By default, the `XmlComponent` class doesn't know anything about Feathers UI. It is meant to be a generic library that can be used with other UI component frameworks too. To add Feathers UI components to the set of available tags, a special build macro must be added to the project.

```hx
import feathers.core.Application;
import com.feathersui.xml.XmlComponent;

@:build(com.feathersui.xml.FeathersUICoreNamespace.setup())
class Main extends Application {
	public function new() {
		var label = XmlComponent.withMarkup(
			<f:Label xmlns:f="http://ns.feathersui.com/xml"
				text="Hello World"/>
		);
		this.addChild(label);
	}
}
```

### `withMarkup()`

Calling the `XmlComponent.withMarkup()` macro generates a Haxe class from inline markup (or from a string), and then it returns a new instance.

```hx
var instance = XmlComponent.withMarkup(
	<f:LayoutGroup>
		<f:layout>
			<f:HorizontalLayout gap="10" horizontalAlign="RIGHT"/>
		</f:layout>
		<f:Button id="okButton" text="OK"/>
		<f:Button id="cancelButton" text="Cancel"/>
	</f:LayoutGroup>
);
container.addChild(instance);
container.okButton.addEventListener(TriggerEvent.TRIGGER, (event) -> {
	trace("triggered the OK button");
});
```

### `withFile()`

Calling the `XmlComponent.withFile()` macro works similarly to `withMarkup()`, but the XML is loaded from a separate file. Relative paths are resolved from the folder containing the _.hx_ file where the macro is used.

```hx
var instance = XmlComponent.withFile("path/to/file.xml");
```

## Haxe primitive types

A subset of core Haxe types may be used in markup by defining the following namespace: 

```
xmlns:hx="http://ns.haxe.org/4/xml"
```

### `Bool`

The value must be `true` or `false`, and it is case-sensitive.

```xml
<hx:Bool>true</hx:Bool>
```

### `Float`

A float may be a positive or negative numeric value which may have a decimal portion.

```xml
<hx:Float>123.4</hx:Float>
```

### `Int`

An integer may be a positive or negative numeric value, and it must not have a decimal portion. Validated by `Std.parseInt()`.

```xml
<hx:Int>-456</hx:Int>
```

### `String`

A sequence of characters.

```xml
<hx:String>Hello World</hx:String>
```

If the string value would make the XML invalid, wrap it with CDATA.

```xml
<hx:String><![CDATA[Some inline HTML<br>that is not valid XML]]></hx:String>
```

### `Dynamic`

An anonymous structure. Properties may be set using XML attributes, child elements, or a combination of both.

```xml
<hx:Dynamic name="Daredevil">
	<hx:secretIdentity>Matt Murdock</hx:secretIdentity>
</hx:Dynamic>
```

### `Array`

An collection of items, which are added as child elements.

```xml
<hx:Array>
	<hx:Dynamic name="Matt Murdock"/>
	<hx:Dynamic name="Foggy Nelson"/>
	<hx:Dynamic name="Karen Page"/>
</hx:Array>
```

## Tips & Tricks

When using [haxe-formatter](https://github.com/HaxeCheckstyle/haxe-formatter), you may want to disable formatting for sections of _.hx_ files that contain embedded markup.

```hx
var instance = XmlComponent.withMarkup(
	// @formatter:off
	<f:LayoutGroup xmlns:f="http://ns.feathersui.com/xml"/>
	// @formatter:on
);
```