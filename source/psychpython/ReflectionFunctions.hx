package psychpython;

import Type.ValueType;
import haxe.Constraints;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import states.PlayState;
import substates.GameOverSubstate;
import psychpython.PyUtils;

using StringTools;

//
// Функции рефлексии (Reflection), интенсивно нагружающие процессор.
// Переписаны и адаптированы под архитектуру среды Python (Hython).
//

class ReflectionFunctions
{
	static final instanceStr:Dynamic = "##PSYCHPYTHON_STRINGTOOBJ";

	public static function implement(funk:psychpython.FunkinPython)
	{
		// Получение значения переменной по строковому пути ("boyfriend.x")
		funk.addLocalCallback("getProperty", function(variable:String, ?allowMaps:Bool = false) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				return PyUtils.getVarInArray(PyUtils.getPropertyLoop(split, true, allowMaps), split[split.length-1], allowMaps);
			return PyUtils.getVarInArray(PyUtils.getTargetInstance(), variable, allowMaps);
		});

		// Изменение значения переменной по строковому пути
		funk.addLocalCallback("setProperty", function(variable:String, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1) {
				PyUtils.setVarInArray(PyUtils.getPropertyLoop(split, true, allowMaps), split[split.length-1], allowInstances ? parseInstances(value) : value, allowMaps);
				return value;
			}
			PyUtils.setVarInArray(PyUtils.getTargetInstance(), variable, allowInstances ? parseInstances(value) : value, allowMaps);
			return value;
		});

		// Получение статического свойства класса напрямую по его имени ("flixel.FlxG", "scoreMultiplier")
		funk.addLocalCallback("getPropertyFromClass", function(classVar:String, variable:String, ?allowMaps:Bool = false) {
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

				return PyUtils.getVarInArray(obj, split[split.length-1], allowMaps);
			}
			return PyUtils.getVarInArray(myClass, variable, allowMaps);
		});

		// Изменение статического свойства класса напрямую по его имени
		funk.addLocalCallback("setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var myClass:Dynamic = Type.resolveClass(classVar);
			if(myClass == null)
			{
				FunkinPython.pythonTrace('setPropertyFromClass: Class $classVar not found', false, false, FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');
			if(split.length > 1) {
				var obj:Dynamic = PyUtils.getVarInArray(myClass, split[0], allowMaps);
				for (i in 1...split.length-1)
					obj = PyUtils.getVarInArray(obj, split[i], allowMaps);

				PyUtils.setVarInArray(obj, split[split.length-1], allowInstances ? parseInstances(value) : value, allowMaps);
				return value;
			}
			PyUtils.setVarInArray(myClass, variable, allowInstances ? parseInstances(value) : value, allowMaps);
			return value;
		});

		// Получение свойства элемента внутри группы или массива по его индексу
		funk.addLocalCallback("getPropertyFromGroup", function(group:String, index:Int, variable:Dynamic, ?allowMaps:Bool = false) {
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
					case TClass(Array): // Объект является обычным массивом Haxe
						var leArray:Dynamic = realObject[index];
						if(leArray != null) {
							var result:Dynamic = null;
							if(Type.typeof(variable) == ValueType.TInt)
								result = leArray[variable];
							else
								result = PyUtils.getGroupStuff(leArray, variable, allowMaps);
							return result;
						}
						FunkinPython.pythonTrace('getPropertyFromGroup: Element $index does not exist instde array or group $group!', false, false, FlxColor.RED);

					default: // Объект является FlxTypedGroup / FlxSpriteGroup
						var result:Dynamic = PyUtils.getGroupStuff(realObject.members[index], variable, allowMaps);
						return result;
				}
			}
			FunkinPython.pythonTrace('getPropertyFromGroup: Group or array $group not found!', false, false, FlxColor.RED);
			return null;
		});

		// Изменение свойства элемента внутри группы или массива по его индексу
		funk.addLocalCallback("setPropertyFromGroup", function(group:String, index:Int, variable:Dynamic, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var split:Array<String> = group.split('.');
			var realObject:Dynamic = null;
			if(split.length > 1)
				realObject = PyUtils.getPropertyLoop(split, false, allowMaps);
			else
				realObject = Reflect.getProperty(PyUtils.getTargetInstance(), group);

			if(realObject != null)
			{
				switch(Type.typeof(realObject))
				{
					case TClass(Array): // Работа с массивом Haxe
						var leArray:Dynamic = realObject[index];
						if(leArray != null)
						{
							if(Type.typeof(variable) == ValueType.TInt)
							{
								leArray[variable] = allowInstances ? parseInstances(value) : value;
								return value;
							}
							PyUtils.setGroupStuff(leArray, variable, allowInstances ? parseInstances(value) : value, allowMaps);
						}

					default: // Работа с FlxGroup.members
						PyUtils.setGroupStuff(realObject.members[index], variable, allowInstances ? parseInstances(value) : value, allowMaps);
				}
			}
			else FunkinPython.pythonTrace('setPropertyFromGroup: Group or array $group not found!', false, false, FlxColor.RED);
			return value;
		});

		// Добавление графического объекта (FlxSprite) в игровую группу или массив
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

		// Удаление объекта из игровой группы с опциональным полным уничтожением (destroy)
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
		
		// Динамический вызов любого метода у любого инстанса на сцене игры
		funk.addLocalCallback("callMethod", function(funcToRun:String, ?args:Array<Dynamic>) {
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

		// Вызов статического метода у Haxe-класса
		funk.addLocalCallback("callMethodFromClass", function(className:String, funcToRun:String, ?args:Array<Dynamic>) {
			return callMethodFromObject(Type.resolveClass(className), funcToRun, parseInstances(args));
		});

		// Создание нового экземпляра класса и сохранение его в глобальные переменные скриптов
		funk.addLocalCallback("createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic>) {
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

// Добавление кастомного сгенерированного инстанса на игровой экран
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
        // Форматирование строкового аргумента под специальный инстанс-тег
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