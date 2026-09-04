package psychpython;

import Type.ValueType;
import haxe.Constraints;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import states.PlayState;
import substates.GameOverSubstate;
import psychpython.PyUtils;

using StringTools;


class ReflectionFunctions
{
	static final instanceStr:Dynamic = "##PSYCHPYTHON_STRINGTOOBJ";

	public static function implement(funk:psychpython.FunkinPython)
	{
		funk.addLocalCallback("finalGetProperty", function(variable:String, ?allowMaps:Bool = false) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				return haxe.Json.stringify(PyUtils.getVarInArray(PyUtils.getPropertyLoop(split, true, allowMaps), split[split.length-1], allowMaps));
			return haxe.Json.stringify(PyUtils.getVarInArray(PyUtils.getTargetInstance(), variable, allowMaps));
		});
		FunkinPython.addPyCode(funk, "
import json
def getProperty(variable: str, allow_maps: bool = False):
	return json.loads(finalGetProperty(variable, allow_maps))
");
		funk.addLocalCallback("finalSetProperty", function(variable:String, valueJson:String, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			
			var split:Array<String> = variable.split('.');
			var value:Dynamic = null;
			try { value = haxe.Json.parse(valueJson); } catch(e:Dynamic) { /*value = valueJson;*/ trace("Error while parsing: " + e); }
			if(split.length > 1) {
				PyUtils.setVarInArray(PyUtils.getPropertyLoop(split, true, allowMaps), split[split.length-1], allowInstances ? parseInstances(value) : value, allowMaps);
				return valueJson;
			}
			PyUtils.setVarInArray(PyUtils.getTargetInstance(), variable, allowInstances ? parseInstances(value) : value, allowMaps);
			return valueJson;
		});
		FunkinPython.addPyCode(funk, "
import json
def setProperty(variable: str, value, allow_maps: bool = False, allow_instances: bool = False):
	
	json_val = f'\\\"{value}\\\"'
	
	finalSetProperty(variable, json_val, allow_maps, allow_instances)
	#the best solution ever
	return value
	
");

		funk.addLocalCallback("finalGetPropertyFromClass", function(classVar:String, variable:String, ?allowMaps:Bool = false) {
			var myClass:Dynamic = Type.resolveClass(classVar);
			if(myClass == null)
			{
				FunkinPython.pythonTrace('getPropertyFromClass: Class $classVar not found', false, false, FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');
			if(split.length > 1) {
				var obj:Dynamic = PyUtils.getVarInArray(myClass, split[0], allowMaps);
				for (i in 1...split.length-1)
					obj = PyUtils.getVarInArray(obj, split[i], allowMaps);

				return haxe.Json.stringify(PyUtils.getVarInArray(obj, split[split.length-1], allowMaps));
			}
			return haxe.Json.stringify(PyUtils.getVarInArray(myClass, variable, allowMaps));
		});
		FunkinPython.addPyCode(funk, "
import json
def getPropertyFromClass(class_var: str, variable: str, allow_maps: bool = False):
	return json.loads(finalGetPropertyFromClass(class_var, variable, allow_maps))
");
		funk.addLocalCallback("finalSetPropertyFromClass", function(classVar:String, variable:String, valueJson:String, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var myClass:Dynamic = Type.resolveClass(classVar);
			if(myClass == null)
			{
				FunkinPython.pythonTrace('setPropertyFromClass: Class $classVar not found', false, false, FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');
			var value:Dynamic= null;
			try { value = haxe.Json.parse(valueJson); } catch(e:Dynamic) {}
			if(split.length > 1) {
				var obj:Dynamic = PyUtils.getVarInArray(myClass, split[0], allowMaps);
				for (i in 1...split.length-1)
					obj = PyUtils.getVarInArray(obj, split[i], allowMaps);

				PyUtils.setVarInArray(obj, split[split.length-1], allowInstances ? parseInstances(value) : value, allowMaps);
				return haxe.Json.stringify(value);
			}
			PyUtils.setVarInArray(myClass, variable, allowInstances ? parseInstances(value) : value, allowMaps);
			return haxe.Json.stringify(value);
		});
		FunkinPython.addPyCode(funk, "
import json
def setPropertyFromClass(class_var: str, variable: str, value, allow_maps: bool = False, allow_instances: bool = False):
	finalSetPropertyFromClass(class_var, variable, f'\\\"{value}\\\"', allow_maps, allow_instances)
	return value
");
		funk.addLocalCallback("finalGetPropertyFromGroup", function(group:String, index:Int, variableJson:String, ?allowMaps:Bool = false) {
			var variable:Dynamic = null;
			try { variable = haxe.Json.parse(variableJson); } catch(e:Dynamic) {}
			var split:Array<String> = group.split('.');
			var realObject:Dynamic = null;
			if(split.length > 1)
				realObject = PyUtils.getPropertyLoop(split, false, allowMaps);
			else
				realObject = Reflect.getProperty(PyUtils.getTargetInstance(), group);

			var groupOrArray:Dynamic = Reflect.getProperty(PyUtils.getTargetInstance(), group);
			if(groupOrArray != null)
			{
				switch(Type.typeof(groupOrArray))
				{
					case TClass(Array):
						var leArray:Dynamic = realObject[index];
						if(leArray != null) {
							var result:Dynamic = null;
							if(Type.typeof(variable) == ValueType.TInt)
								result = leArray[variable];
							else
								result = PyUtils.getGroupStuff(leArray, variable, allowMaps);
							return haxe.Json.stringify(result);
						}
						FunkinPython.pythonTrace('getPropertyFromGroup: Element $index does not exist instde array or group $group!', false, false, FlxColor.RED);

					default:
						var result:Dynamic = PyUtils.getGroupStuff(realObject.members[index], variable, allowMaps);
						return haxe.Json.stringify(result);
				}
			}
			FunkinPython.pythonTrace('getPropertyFromGroup: Group or array $group not found!', false, false, FlxColor.RED);
			return null;
		});
		FunkinPython.addPyCode(funk, "
import json
def getPropertyFromGroup(group: str, index: int, variable, allow_maps: bool = False):
	return json.loads(finalGetPropertyFromGroup(group, index, json.dumps(variable), allow_maps))
");
		funk.addLocalCallback("finalSetPropertyFromGroup", function(group:String, index:Int, variableJson:String, valueJson:String, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var split:Array<String> = group.split('.');
			var realObject:Dynamic = null;
			var variable:Dynamic = null;
			var value:Dynamic = null;
			try { variable = haxe.Json.parse(variableJson); } catch(e:Dynamic) {}
			try { value = haxe.Json.parse(valueJson); } catch(e:Dynamic) {}
			if(split.length > 1)
				realObject = PyUtils.getPropertyLoop(split, false, allowMaps);
			else
				realObject = Reflect.getProperty(PyUtils.getTargetInstance(), group);

			if(realObject != null)
			{
				switch(Type.typeof(realObject))
				{
					case TClass(Array):
						var leArray:Dynamic = realObject[index];
						if(leArray != null)
						{
							if(Type.typeof(variable) == ValueType.TInt)
							{
								leArray[variable] = allowInstances ? parseInstances(value) : value;
								return haxe.Json.stringify(value);
							}
							PyUtils.setGroupStuff(leArray, variable, allowInstances ? parseInstances(value) : value, allowMaps);
						}

					default:
						PyUtils.setGroupStuff(realObject.members[index], variable, allowInstances ? parseInstances(value) : value, allowMaps);
				}
			}
			else FunkinPython.pythonTrace('setPropertyFromGroup: Group or array $group not found!', false, false, FlxColor.RED);
			return haxe.Json.stringify(value);
		});
		FunkinPython.addPyCode(funk, "
import json
def setPropertyFromGroup(group: str, index: int, variable, value, allow_maps: bool = False, allow_instances: bool = False):
	finalSetPropertyFromGroup(group, index, f'\\\"{value}\\\"', json.dumps(value, ensure_ascii=False), allow_maps, allow_instances)
	return value
");
		funk.addLocalCallback("addToGroup", function(group:String, tag:String, ?index:Int = -1) {
			var obj:FlxSprite = PyUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null)
			{
				FunkinPython.pythonTrace('addToGroup: Sprite $tag invalid or deleted!', false, false, FlxColor.RED);
				return;
			}

			var groupOrArray:Dynamic = Reflect.getProperty(PyUtils.getTargetInstance(), group);
			if(groupOrArray == null)
			{
				FunkinPython.pythonTrace('addToGroup: Target group $group not found on stage!', false, false, FlxColor.RED);
				return;
			}

			if(index < 0)
			{
				switch(Type.typeof(groupOrArray))
				{
					case TClass(Array):
						groupOrArray.push(obj);
					default:
						groupOrArray.add(obj);
				}
			}
			else groupOrArray.insert(index, obj);
		});

		funk.addLocalCallback("removeFromGroup", function(group:String, ?index:Int = -1, ?tag:String = null, ?destroy:Bool = true) {
			var obj:FlxSprite = null;
			if(tag != null)
			{
				obj = PyUtils.getObjectDirectly(tag);
				if(obj == null || obj.destroy == null)
				{
					FunkinPython.pythonTrace('removeFromGroup: Sprite $tag invalid!', false, false, FlxColor.RED);
					return;
				}
			}

			var groupOrArray:Dynamic = Reflect.getProperty(PyUtils.getTargetInstance(), group);
			if(groupOrArray == null)
			{
				FunkinPython.pythonTrace('removeFromGroup: Target group $group not found!', false, false, FlxColor.RED);
				return;
			}

			switch(Type.typeof(groupOrArray))
			{
				case TClass(Array):
					if(obj != null)
					{
						groupOrArray.remove(obj);
						if(destroy) obj.destroy();
					}
					else groupOrArray.remove(groupOrArray[index]);

				default:
					if(obj == null) obj = groupOrArray.members[index];
					groupOrArray.remove(obj, true);
					if(destroy) obj.destroy();
			}
		});
		
		funk.addLocalCallback("finalCallMethod", function(funcToRun:String, ?argsJson:String) {
			var args:Array<Dynamic> = [];
			try { args = haxe.Json.parse(argsJson); } catch (e:Dynamic){}
			var parent:Dynamic = PlayState.instance;
			var split:Array<String> = funcToRun.split('.');
			var varParent:Dynamic = MusicBeatState.getVariables().get(split[0].trim());
			if (varParent != null) {
				split.shift();
				funcToRun = split.join('.').trim();
				parent = varParent;
			}
			
			if(funcToRun.length > 0) {
				return callMethodFromObject(parent, funcToRun, parseInstances(args));
			}
			return Reflect.callMethod(null, parent, parseInstances(args));
		});
		FunkinPython.addPyCode(funk, "
import json
def callMethod(func_to_run, args):
	return finalCallMethod(func_to_run, json.dumps(args, ensure_ascii=False))
");
		funk.addLocalCallback("finalCallMethodFromClass", function(className:String, funcToRun:String, ?argsJson:String) {
			var args:Array<Dynamic> = [];
			try{ args = haxe.Json.parse(argsJson); } catch(e:Dynamic) {}
			return callMethodFromObject(Type.resolveClass(className), funcToRun, parseInstances(args));
		});
		FunkinPython.addPyCode(funk, "
import json
def callMethodFromObject(class_name, func_to_run, args):
	return finalCallMethodFromClass(class_name, func_to_run, json.dumps(args))
");
		funk.addLocalCallback("finalCreateInstance", function(variableToSave:String, className:String, ?argsJson:String) {
			var args:Array<Dynamic> = [];
			try { args = haxe.Json.parse(argsJson); } catch(e:Dynamic) {}
			if (!Std.isOfType(args, Array)) args = [];
			variableToSave = variableToSave.trim().replace('.', '');
			if(MusicBeatState.getVariables().get(variableToSave) == null)
			{
				if(args == null) args = [];
				var myType:Dynamic = Type.resolveClass(className);
		
				if(myType == null)
				{
					FunkinPython.pythonTrace('createInstance: Class $className not found', false, false, FlxColor.RED);
					return false;
				}

				var obj:Dynamic = Type.createInstance(myType, parseInstances(args));
				if(obj != null)
					MusicBeatState.getVariables().set(variableToSave, obj);
				else
					FunkinPython.pythonTrace('createInstance: Couldn not create $variableToSave, maybe incorrect arguments.', false, false, FlxColor.RED);

				return (obj != null);
			}
			else FunkinPython.pythonTrace('createInstance: Variable $variableToSave already uses and cannot be rewritten!', false, false, FlxColor.RED);
			return false;
		});
		FunkinPython.addPyCode(funk, "
import json
def createInstance(variable_to_save, class_name, args):
	return finalCreateInstance(variable_to_save, class_name, json.dumps(args))
");

        funk.addLocalCallback("addInstance", function(objectName:String, ?inFront:Bool = false) {
            var savedObj:Dynamic = MusicBeatState.getVariables().get(objectName);
            if(savedObj != null){
                var obj:Dynamic = savedObj;
                if (inFront)PyUtils.getTargetInstance().add(obj);
                else{
                    if(!PlayState.instance.isDead)PlayState.instance.insert(PlayState.instance.members.indexOf(PyUtils.getLowestCharacterGroup()), obj);
                    else
						GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), obj);
                }
            }
            else FunkinPython.pythonTrace('addInstance: Cannot add something that does not exist. ($objectName)', false, false, FlxColor.RED);
        });

        funk.addLocalCallback("instanceArg", function(instanceName:String, ?className:String = null) {
            var retStr:String = '$instanceStr::$instanceName';
            if(className != null) retStr += '::$className';
            return retStr;
        });
    }
    static function parseInstanceArray(arg:Array<Dynamic>) {
        var newArray:Array<Dynamic> = [];
        for (val in arg)newArray.push(parseInstances(val));
        return newArray;
    }
    public static function parseInstances(arg:Dynamic):Dynamic {
        if (arg == null) return null;
        if (Std.isOfType(arg, Array)) {
            return parseInstanceArray(arg);
        } else {
            return parseSingleInstance(arg);
        }
    }
    public static function parseSingleInstance(arg:Dynamic):Dynamic{
        if (Std.isOfType(arg, String)) {
            var argStr:String = cast arg;
            if(argStr != null && argStr.length > instanceStr.length){
                var index:Int = argStr.indexOf('::');
                if(index > -1){
                    argStr = argStr.substring(index+2);
                    var lastIndex:Int = argStr.lastIndexOf('::');
                    var split:Array<Dynamic> = (lastIndex > -1) ? argStr.substring(0, lastIndex).split('.') : argStr.split('.');
                    arg = (lastIndex > -1) ? Type.resolveClass(argStr.substring(lastIndex+2)) : PlayState.instance;
                    for (j in 0...split.length){
                        arg = PyUtils.getVarInArray(arg, split[j].trim());
                    }
                }
            }
        }
        return arg;
    }
    static function callMethodFromObject(classObj:Dynamic, funcStr:String, args:Array<Dynamic>):Dynamic{
        var split:Array<Dynamic> = funcStr.split('.');
        var funcToRun:Function = null;
        var obj:Dynamic = classObj;
        if(obj == null){
            return null;
        }
        for (i in 0...split.length){
            obj = PyUtils.getVarInArray(obj, split[i].trim());
        }
        funcToRun = cast obj;
        return funcToRun != null ? Reflect.callMethod(obj, funcToRun, args) : null;
    }
}