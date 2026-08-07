package psychpython;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import objects.Character;
import psychpython.PyUtils;
import psychlua.CustomSubstate;
import sys.io.File;
import sys.FileSystem;
import states.PlayState;
import substates.GameOverSubstate;
import backend.Mods;
import backend.Paths;

using StringTools;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;

import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import haxe.ValueException;

typedef HScriptInfos = {
	> haxe.PosInfos,
	var ?funcName:String;
	var ?showLine:Null<Bool>;
	var ?isPython:Null<Bool>;
}

class HScript extends Iris
{
	public var filePath:String;
	public var modFolder:String;
	public var returnValue:Dynamic;
	public var parentPython:psychpython.FunkinPython;

	public static function initHaxeModule(parent:psychpython.FunkinPython)
	{
		if(parent.hscript == null)
		{
			trace('Initializing Haxe interp for Python script: ${parent.scriptName}');
			parent.hscript = new HScript(parent);
		}
	}

	public static function initHaxeModuleCode(parent:psychpython.FunkinPython, code:String, ?varsToBring:Any = null)
	{
		var hs:HScript = try parent.hscript catch (e) null;
		if(hs == null)
		{
			trace('Initializing Haxe interp code for Python script: ${parent.scriptName}');
			try {
				parent.hscript = new HScript(parent, code, varsToBring);
			}
			catch(e:IrisError) {
				var pos:HScriptInfos = cast {fileName: parent.scriptName, isPython: true};
				Iris.error(Printer.errorToString(e, false), pos);
				parent.hscript = null;
			}
		}
		else
		{
			try
			{
				hs.scriptCode = code;
				hs.varsToBring = varsToBring;
				hs.parse(true);
				var ret:Dynamic = hs.execute();
				hs.returnValue = ret;
			}
			catch(e:IrisError)
			{
				var pos:HScriptInfos = cast hs.interp.posInfos();
				pos.isPython = true;
				Iris.error(Printer.errorToString(e, false), pos);
				hs.returnValue = null;
			}
		}
	}

	public var origin:String;
	override public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false)
	{
		if (file == null)
			file = '';

		filePath = file;
		if (filePath != null && filePath.length > 0)
		{
			this.origin = filePath;
			#if MODS_ALLOWED
			var myFolder:Array<String> = filePath.split('/');
			if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1])))
				this.modFolder = myFolder[1];
			#end
		}
		var scriptThing:String = file;
		var scriptName:String = null;
		if(parent == null && file != null)
		{
			var f:String = file.replace('\\', '/');
			if(f.contains('/') && !f.contains('\n') && FileSystem.exists(f)) {
				scriptThing = File.getContent(f);
				scriptName = f;
			}
		}
		if (scriptName == null && parent != null)
			scriptName = parent.scriptName;

		super(scriptThing, new IrisConfig(scriptName, false, false));
		
		var customInterp:CustomInterp = new CustomInterp();
		customInterp.parentInstance = FlxG.state;
		customInterp.showPosOnLog = false;
		this.interp = customInterp;
		
		parentPython = parent;
		if (parent != null)
		{
			this.origin = parent.scriptName;
			this.modFolder = parent.modFolder;
		}
		
		preset();
		this.varsToBring = varsToBring;
		if (!manualRun) {
			try {
				var ret:Dynamic = execute();
				returnValue = ret;
			} catch(e:IrisError) {
				returnValue = null;
				this.destroy();
				throw e;
			}
		}
	}

	var varsToBring(default, set):Any = null;
	override function preset() {
		super.preset();

		// Стандартные классы Psych Engine
		set('Type', Type);
		#if sys
		set('File', File);
		set('FileSystem', FileSystem);
		#end
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxText', flixel.text.FlxText);
		set('FlxCamera', flixel.FlxCamera);
		set('PsychCamera', backend.PsychCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('Countdown', backend.BaseStage.Countdown);
		set('PlayState', PlayState);
		set('Paths', Paths);
		set('Conductor', Conductor);
		set('ClientPrefs', ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		set('Character', Character);
		set('Alphabet', Alphabet);
		set('Note', objects.Note);
		set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		set('ErrorHandledRuntimeShader', shaders.ErrorHandledShader.ErrorHandledRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('StringTools', StringTools);
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		#end

		// Функционал переменных
		set('setVar', function(name:String, value:Dynamic) {
			MusicBeatState.getVariables().set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			var result:Dynamic = null;
			if(MusicBeatState.getVariables().exists(name)) result = MusicBeatState.getVariables().get(name);
			return result;
		});
		set('removeVar', function(name:String) {
			if(MusicBeatState.getVariables().exists(name)) {
				MusicBeatState.getVariables().remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			if(PlayState.instance != null) PlayState.instance.addTextToDebug(text, color);
		});
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null) {
				if(this.modFolder == null) {
					Iris.error('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', this.interp.posInfos());
					return null;
				}
				modName = this.modFolder;
			}
			return PyUtils.getModSetting(saveTag, modName);
		});

		// Ввод: Клавиатура и Геймпады
		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;
			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;
			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;
			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;
			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;
			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		set('keyPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		set('keyReleased', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});

		set('createGlobalCallback', function(name:String, func:Dynamic) {
			for (script in PlayState.instance.pythonArray)
				if(script != null && !script.closed)
					script.addLocalCallback(name, func);

			psychpython.FunkinPython.customFunctions.set(name, func);
		});

		set('createCallback', function(name:String, func:Dynamic, ?funk:psychpython.FunkinPython = null) {
			if(funk == null) funk = parentPython;
			if(funk != null) funk.addLocalCallback(name, func);
			else Iris.error('createCallback ($name): 3rd argument is null', this.interp.posInfos());
		});

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0) str = libPackage + '.';
				set(libName, Type.resolveClass(str + libName));
			} catch (e:IrisError) {
				Iris.error(Printer.errorToString(e, false), this.interp.posInfos());
			}
		});

		set('parentPython', parentPython);
		set('this', this);
		set('game', FlxG.state);
		set('controls', Controls.instance);
		set('buildTarget', PyUtils.getBuildTarget());
        set('customSubstate', CustomSubstate.instance);
        set('customSubstateName', CustomSubstate.name);
        set('Function_Stop', PyUtils.Function_Stop);
        set('Function_Continue', PyUtils.Function_Continue);
        set('Function_StopPython', PyUtils.Function_StopPython);
        set('Function_StopHScript', PyUtils.Function_StopHScript);
        set('Function_StopAll', PyUtils.Function_StopAll);
    }
    public static function implement(funk:psychpython.FunkinPython) 
    {
        funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
            initHaxeModuleCode(funk, codeToRun, varsToBring);
            if (funk.hscript != null){
                final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
                if (retVal != null) return (PyUtils.isPythonSupported(retVal.returnValue)) ? retVal.returnValue : null;
                else if (funk.hscript.returnValue != null) return funk.hscript.returnValue;
            }
            return null;});
            funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
                if (funk.hscript != null){
                    final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
                    if (retVal != null) return (PyUtils.isPythonSupported(retVal.returnValue)) ? retVal.returnValue : null;
                } else {
                    var pos:HScriptInfos = cast {
                        fileName: funk.scriptName, 
                        showLine: false
                    };
                    Iris.error("runHaxeFunction: HScript has not been initialized yet! Use 'runHaxeCode' to initialize it", pos);
                }
                return null;
            });
            funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
                var str:String = '';
                if (libPackage.length > 0) str = libPackage + '.';
                else if (libName == null) libName = '';
                var c:Dynamic = Type.resolveClass(str + libName);
                if (c == null) c = Type.resolveEnum(str + libName);
                if (funk.hscript == null) initHaxeModule(funk);
                var pos:HScriptInfos = cast funk.hscript.interp.posInfos();
                pos.showLine = false;
                try {
                    if (c != null) funk.hscript.set(libName, c);
                } catch (e:IrisError) {
                    Iris.error(Printer.errorToString(e, false), pos);
                }
            });
        }
        override function call(funcToRun:String, ?args:Array<Dynamic>):IrisCall {
            if (funcToRun == null || interp == null) return null;
            if (!exists(funcToRun)) return null;
            try {
                var func:Dynamic = interp.variables.get(funcToRun);
                final ret = Reflect.callMethod(null, func, args ?? []);
                return {
                    funName: funcToRun, 
                    signature: func, 
                    returnValue: ret
                };
            } catch(e:IrisError) {
                var pos:HScriptInfos = cast this.interp.posInfos();
                pos.funcName = funcToRun;
                if (parentPython != null) pos.isPython = true;
                Iris.error(Printer.errorToString(e, false), pos);
            } catch (e:ValueException) {
                var pos:HScriptInfos = cast this.interp.posInfos();
                pos.funcName = funcToRun;
                if (parentPython != null) pos.isPython = true;
                Iris.error('$e', pos);
            }
            return null;
        }
    override public function destroy(){
        origin = null;
        parentPython = null;
        super.destroy();
    }
    function set_varsToBring(values:Any) {
        if (varsToBring != null)
            for (key in Reflect.fields(varsToBring))
                if (exists(key.trim()))
                    interp.variables.remove(key.trim());
        if (values != null)
        {
            for (key in Reflect.fields(values))
            {   
                var k = key.trim();
                set(k, Reflect.field(values, key));
            }
        }
        return varsToBring = values;
    }
}
class CustomInterp extends crowplexus.hscript.Interp{
    public var parentInstance(default, set):Dynamic = [];
    private var _instanceFields:Array<Dynamic>;
    function set_parentInstance(inst:Dynamic):Dynamic{
        parentInstance = inst;
        if(parentInstance == null){
            _instanceFields = [];
            return inst;
        }
        _instanceFields = Type.getInstanceFields(Type.getClass(inst));
        return inst;
    }
    public function new() { super(); }
    override function fcall(o:Dynamic, funcToRun:String, args:Array<Dynamic>):Dynamic {
        for (_using in usings) {
            var v = _using.call(o, funcToRun, args);
            if (v != null) return v;
        }
        var f = get(o, funcToRun);
        if (f == null) {
            Iris.error('Tried to call null function $funcToRun', posInfos());
            return null;
        }
        return Reflect.callMethod(o, f, args);
    }
    override function resolve(id: String): Dynamic {
        if (locals.exists(id)) return locals.get(id).r;
        if (variables.exists(id)) return variables.get(id);
        if (imports.exists(id)) return imports.get(id);
        if (parentInstance != null && _instanceFields.contains(id)) return Reflect.getProperty(parentInstance, id);
        error(EUnknownVariable(id));
        return null;
    }
}// Класс для экспорта цветов в скрипты
class CustomFlxColor {
    public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;
		public static function fromInt(Value:Int):Int 
		return cast FlxColor.fromInt(Value);

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);

	public static function fromString(str:String):Int
		return cast FlxColor.fromString(str);
}
#end