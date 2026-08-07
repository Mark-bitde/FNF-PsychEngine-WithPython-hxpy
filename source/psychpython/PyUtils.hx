package psychpython;

import backend.WeekData;
import objects.Character;
import backend.StageData;
import openfl.display.BlendMode;
import Type.ValueType;
import sys.FileSystem;
import sys.io.File;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import states.PlayState;
import substates.GameOverSubstate;
import backend.Mods;
import backend.Paths;

using StringTools;

// Структура параметров Tween анимаций для Python
typedef PyTweenOptions = {
	type:FlxTweenType,
	startDelay:Float,
	onUpdate:Null<String>,
	onStart:Null<String>,
	onComplete:Null<String>,
	loopDelay:Float,
	ease:EaseFunction
}

class PyUtils
{
	// Константы управления выполнением скриптов
	public static final Function_Stop:String = "##PSYCHPYTHON_FUNCTIONSTOP";
	public static final Function_Continue:String = "##PSYCHPYTHON_FUNCTIONCONTINUE";
	public static final Function_StopPython:String = "##PSYCHPYTHON_FUNCTIONSTOPPYTHON";
	public static final Function_StopHScript:String = "##PSYCHPYTHON_FUNCTIONSTOPHSCRIPT";
	public static final Function_StopAll:String = "##PSYCHPYTHON_FUNCTIONSTOPALL";

	// Ссылка на последний запущенный или вызвавший метод скрипт для дебага
	public static var lastCalledScript:FunkinPython = null;
	public static function getPyTween(options:Dynamic)
	{
		return (options != null) ? {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getTweenEaseByString(options.ease)
		} : null;
	}
	public static function cameraFromString(cam:String):FlxCamera {
		switch(cam.toLowerCase()) {
			case 'camgame' | 'game': return PlayState.instance.camGame;
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
		}
		var camera:FlxCamera = MusicBeatState.getVariables().get(cam);
		if (camera == null || !Std.isOfType(camera, FlxCamera)) camera = PlayState.instance.camGame;
		return camera;
	}
	// --- Логирование и утилиты ---

	/**
	 * Безопасно выводит текст в дебаг-консоль на экране игры.
	 */
	public static function pythonTrace(text:String, ?color:FlxColor = FlxColor.WHITE):Void {
		var game = PlayState.instance;
		if (game != null) game.addTextToDebug(text, color);
		else trace(text);
	}

	/**
	 * Проверяет, является ли переданный объект картой (Map).
	 */
	public static function isMap(variable:Dynamic):Bool {
		return (variable != null && Reflect.hasField(variable, "exists") && Reflect.hasField(variable, "keyValueIterator"));
	}

	/**
	 * Проверяет, поддерживается ли тип данных интерпретатором Hython.
	 */
	public static function isPythonSupported(value:Any):Bool {
		return (value == null || isOfTypes(value, [Bool, Int, Float, String, Array]) || Type.typeof(value) == ValueType.TObject);
	}
	
	/**
	 * Получает ссылку на текущее активное состояние игры (PlayState или GameOverSubstate).
	 */
	public static function getTargetInstance()
	{
		if(PlayState.instance != null) return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
		return MusicBeatState.getState();
	}

	/**
	 * Находит группу персонажей с самым низким приоритетом отрисовки на сцене.
	 */
	public static inline function getLowestCharacterGroup():FlxSpriteGroup
	{
		var stageData:StageFile = StageData.getStageFile(PlayState.SONG.stage);
		var group:FlxSpriteGroup = (stageData.hide_girlfriend ? PlayState.instance.boyfriendGroup : PlayState.instance.gfGroup);

		var pos:Int = PlayState.instance.members.indexOf(group);

		var newPos:Int = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.boyfriendGroup;
			pos = newPos;
		}
		
		newPos = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.dadGroup;
			pos = newPos;
		}
		return group;
	}

	// --- Работа со свойствами и рефлексией (Reflect) ---

	/**
	 * Динамически устанавливает значение переменной внутри объекта, массива или карты (Map).
	 */
	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic, allowMaps:Bool = false):Any
	{
		var splitProps:Array<String> = variable.split('[');
		if(splitProps.length > 1)
		{
			var target:Dynamic = null;
			if(MusicBeatState.getVariables().exists(splitProps[0]))
			{
				var retVal:Dynamic = MusicBeatState.getVariables().get(splitProps[0]);
				if(retVal != null)
					target = retVal;
			}
			else target = Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				if(i >= splitProps.length-1) // Последний индекс массива
					target[j] = value;
				else // Промежуточные объекты
					target = target[j];
			}
			return target;
		}

		if(allowMaps && isMap(instance))
		{
			instance.set(variable, value);
			return value;
		}

		if(instance is MusicBeatState && MusicBeatState.getVariables().exists(variable))
		{
			MusicBeatState.getVariables().set(variable, value);
			return value;
		}
		Reflect.setProperty(instance, variable, value);
		return value;
	}

	/**
	 * Динамически читает значение переменной из объекта, массива или карты (Map).
	 */
	public static function getVarInArray(instance:Dynamic, variable:String, allowMaps:Bool = false):Any
	{
		var splitProps:Array<String> = variable.split('[');
		if(splitProps.length > 1)
		{
			var target:Dynamic = null;
			if(MusicBeatState.getVariables().exists(splitProps[0]))
			{
				var retVal:Dynamic = MusicBeatState.getVariables().get(splitProps[0]);
				if(retVal != null)
					target = retVal;
			}
			else
				target = Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				target = target[j];
			}
			return target;
		}
		
		if(allowMaps && isMap(instance))
		{
			return instance.get(variable);
		}

		if(instance is MusicBeatState && MusicBeatState.getVariables().exists(variable))
		{
			var retVal:Dynamic = MusicBeatState.getVariables().get(variable);
			if(retVal != null)
				return retVal;
		}
		return Reflect.getProperty(instance, variable);
	}

	/**
	 * Возвращает объект по его строковому имени на сцене.
	 */
	public static function getObjectDirectly(objectName:String, ?allowMaps:Bool = false):Dynamic
	{
		switch(objectName)
		{
			case 'this' | 'instance' | 'game':
				return PlayState.instance;
			
			default:
				var obj:Dynamic = MusicBeatState.getVariables().get(objectName);
				if(obj == null) obj = getVarInArray(MusicBeatState.getState(), objectName, allowMaps);
				return obj;
		}
	}

	/**
	 * Рекурсивно проходит по цепочке свойств ("boyfriend.frameWidth").
	 */
	public static function getPropertyLoop(split:Array<String>, ?getProperty:Bool=true, ?allowMaps:Bool = false):Dynamic
	{
		var obj:Dynamic = getObjectDirectly(split[0]);
		var end = split.length;
		if(getProperty) end = split.length-1;

		for (i in 1...end) obj = getVarInArray(obj, split[i], allowMaps);
		return obj;
	}

	// --- Анимации, Спрайты и Атласы ---
	
	/**
	 * Генерирует анимацию для FlxSprite по переданной строке или массиву индексов кадров.
	 */
	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:Any = null, framerate:Float = 24, loop:Bool = false)
	{
		var sprite:FlxSprite = cast getObjectDirectly(obj);
		if(sprite != null && sprite.animation != null)
		{
			if(indices == null)
				indices = [];
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}
				indices = myIndices;
			}

			if(prefix != null) sprite.animation.addByIndices(name, prefix, indices, '', framerate, loop);
			else sprite.animation.add(name, indices, framerate, loop);

			if(sprite.animation.curAnim == null)
			{
				var dyn:Dynamic = cast sprite;
				if(dyn.playAnim != null) dyn.playAnim(name, true);
				else dyn.animation.play(name, true);
			}
			return true;
		}
		return false;
	}
	
	/**
	 * Автоматически подгружает правильный тип графического атласа для спрайта.
	 */
	public static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().replace(' ', ''))
		{
			case 'aseprite', 'ase', 'json', 'jsoni8':
				spr.frames = Paths.getAsepriteAtlas(image);

			case "packer", 'packeratlas', 'pac':
				spr.frames = Paths.getPackerAtlas(image);

			case 'sparrow', 'sparrowatlas', 'sparrowv2':
				spr.frames = Paths.getSparrowAtlas(image);

			default:
				spr.frames = Paths.getAtlas(image);
		}
	}

	/**
	 * Полностью уничтожает объект и удаляет его с экрана по его тегу.
	 */
	public static function destroyObject(tag:String) {
		var variables = MusicBeatState.getVariables();
		var obj:FlxSprite = variables.get(tag);
		if(obj == null || obj.destroy == null)
			return;

		getTargetInstance().remove(obj, true);
		obj.destroy();
		variables.remove(tag);
	}

	// --- Таймеры, Твины и Системные настройки ---

	public static function cancelTween(tag:String) {
		if(!tag.startsWith('tween_')) tag = 'tween_' + formatVariable(tag);
		var variables = MusicBeatState.getVariables();
		var twn:FlxTween = variables.get(tag);
		if(twn != null)
		{
			twn.cancel();
			twn.destroy();
			variables.remove(tag);
		}
	}

	public static function cancelTimer(tag:String) {
		if(!tag.startsWith('timer_')) tag = 'timer_' + formatVariable(tag);
		var variables = MusicBeatState.getVariables();
		var tmr:FlxTimer = variables.get(tag);
		if(tmr != null)
		{
			tmr.cancel();
			tmr.destroy();
			variables.remove(tag);
		}
	}

	public static function formatVariable(tag:String) {
		return tag.trim().replace(' ', '_').replace('.', '');
	}

	public static function tweenPrepare(tag:String, vars:String) {
		if(tag != null) cancelTween(tag);
		var variables:Array<String> = vars.split('.');
		var sexyProp:Dynamic = getObjectDirectly(variables[0]);
		if(variables.length > 1) sexyProp = getVarInArray(getPropertyLoop(variables), variables[variables.length-1]);
		return sexyProp;
	}

	/**
	 * Возвращает текущую ОС, под которую собирается игра (нужно для Python переменных среды).
	 */
	public static function getGroupStuff(leArray:Dynamic, variable:String, ?allowMaps:Bool = false) {
		var split:Array<String> = variable.split('.');
		if(split.length > 1) {
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1)
				obj = Reflect.getProperty(obj, split[i]);

			leArray = obj;
			variable = split[split.length-1];
		}

		if(allowMaps && isMap(leArray)) return leArray.get(variable);
		return Reflect.getProperty(leArray, variable);
	}
	public static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic, ?allowMaps:Bool = false) {
		var split:Array<String> = variable.split('.');
		if(split.length > 1) {
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1)
				obj = Reflect.getProperty(obj, split[i]);

			leArray = obj;
			variable = split[split.length-1];
		}
		if(allowMaps && isMap(leArray)) leArray.set(variable, value);
		else Reflect.setProperty(leArray, variable, value);
		return value;
	}
	public static function getBuildTarget():String
	{
		#if windows
		#if x86_BUILD
		return 'windows_x86';
		#else
		return 'windows';
		#end
		#elseif linux
		return 'linux';
		#elseif mac
		return 'mac';
		#elseif html5
		return 'browser';
		#elseif android
		return 'android';
        #elseif switch
        return 'switch';
        #else
        return 'unknown';
        #end
    }
    public static function getTweenTypeByString(?type:String = '') 
    {
        switch(type.toLowerCase().trim())
        {
            case 'backward': 
                return FlxTweenType.BACKWARD;
            case 'looping'|'loop': 
                return FlxTweenType.LOOPING;
            case 'persist': 
                return FlxTweenType.PERSIST;
            case 'pingpong': 
                return FlxTweenType.PINGPONG;
        }
        return FlxTweenType.ONESHOT;
    }
    /*** Возвращает функцию плавности (Ease) на основе строкового имени.*/
    public static function getTweenEaseByString(?ease:String = '') 
    {
        var easeName = ease.toLowerCase().trim();
        // Использование рефлексии для поиска функции в FlxEase
        var field = Reflect.field(FlxEase, easeName);
        if (field != null) return field;
        return FlxEase.linear;
    }
	public static function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types)
		{
			if(Std.isOfType(value, type)) return true;
		}
		return false;
	}
	public static function blendModeFromString(blend:String):BlendMode {
		switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
		}
		return NORMAL;
	}
		public static function getModSetting(saveTag:String, ?modName:String = null)
	{
		#if MODS_ALLOWED
		if(FlxG.save.data.modSettings == null) FlxG.save.data.modSettings = new Map<String, Dynamic>();

		var settings:Map<String, Dynamic> = FlxG.save.data.modSettings.get(modName);
		var path:String = Paths.mods('$modName/data/settings.json');
		if(FileSystem.exists(path))
		{
			if(settings == null || !settings.exists(saveTag))
			{
				if(settings == null) settings = new Map<String, Dynamic>();
				var data:String = File.getContent(path);
				try
				{
					//FunkinLua.luaTrace('getModSetting: Trying to find default value for "$saveTag" in Mod: "$modName"');
					var parsedJson:Dynamic = tjson.TJSON.parse(data);
					for (i in 0...parsedJson.length)
					{
						var sub:Dynamic = parsedJson[i];
						if(sub != null && sub.save != null && !settings.exists(sub.save))
						{
							if(sub.type != 'keybind' && sub.type != 'key')
							{
								if(sub.value != null)
								{
									//FunkinLua.luaTrace('getModSetting: Found unsaved value "${sub.save}" in Mod: "$modName"');
									settings.set(sub.save, sub.value);
								}
							}
							else
							{
								//FunkinLua.luaTrace('getModSetting: Found unsaved keybind "${sub.save}" in Mod: "$modName"');
								settings.set(sub.save, {keyboard: (sub.keyboard != null ? sub.keyboard : 'NONE'), gamepad: (sub.gamepad != null ? sub.gamepad : 'NONE')});
							}
						}
					}
					FlxG.save.data.modSettings.set(modName, settings);
				}
				catch(e:Dynamic)
				{
					var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
					var errorMsg = 'An error occurred: $e';
					#if windows
					lime.app.Application.current.window.alert(errorMsg, errorTitle);
					#end
					trace('$errorTitle - $errorMsg');
				}
			}
		}
		else
		{
			FlxG.save.data.modSettings.remove(modName);
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			PlayState.instance.addTextToDebug('getModSetting: $path could not be found!', FlxColor.RED);
			#else
			FlxG.log.warn('getModSetting: $path could not be found!');
			#end
			return null;
		}

		if(settings.exists(saveTag)) return settings.get(saveTag);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED || PYTHON_ALLOWED)
		PlayState.instance.addTextToDebug('getModSetting: "$saveTag" could not be found inside $modName\'s settings!', FlxColor.RED);
		#else
		FlxG.log.warn('getModSetting: "$saveTag" could not be found inside $modName\'s settings!');
		#end
		#end
		return null;
	}
} // Закрытие класса PyUtils