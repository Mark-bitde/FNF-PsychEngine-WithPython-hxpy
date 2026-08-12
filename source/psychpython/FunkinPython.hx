
#if PYTHON_ALLOWED
package psychpython;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import cpp.RawPointer;
import openfl.Lib;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.FlxCamera;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

import cutscenes.DialogueBoxPsych;

import objects.StrumNote;
import objects.Note;
import objects.NoteSplash;
import objects.Character;

import states.MainMenuState;
import states.StoryMenuState;
import states.FreeplayState;

import substates.PauseSubState;
import substates.GameOverSubstate;

import psychpython.PyUtils;
import psychpython.PyUtils.PyTweenOptions;
#if HSCRIPT_ALLOWED
import psychpython.HScript;
#end
import psychpython.DebugPyText;
import psychpython.ModchartSprite;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import haxe.Json;
import hxpy.*;
import sys.io.File;
import sys.FileSystem;
import states.PlayState;
import backend.Mods;
import backend.Paths;

using StringTools;

class FunkinPython {
	private static var functionRegistry:Map<Int, Dynamic> = new Map();
	private static var nextFunctionId:Int = 0;
	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var scriptFile:String = '';
	public var modFolder:String = null;
	public var closed:Bool = false;
	public var result:Bool = false;
	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	#end
	
	public var callbacks:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static var lastCalledScript:FunkinPython = null;

	public function new(scriptName:String) {
		// Python(Hython) init
		
		
		this.scriptName = scriptName.trim();
		this.scriptFile = scriptName;
        if (!Py.isInitialized()) {
            Py.initialize();
        }
		var game:PlayState = PlayState.instance;
        if(game != null && game.pythonArray != null) {
            game.pythonArray.push(this);
        }
		var myFolder:Array<String> = this.scriptFile.split('/');
		#if MODS_ALLOWED
		if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1])))
			this.modFolder = myFolder[1];
		#end
		
		// Python shit 
		
		set('Function_StopLua', psychlua.LuaUtils.Function_StopLua);
		set('Function_StopPython', PyUtils.Function_StopPython);
		set('Function_StopHScript', PyUtils.Function_StopHScript);
		set('Function_StopAll', PyUtils.Function_StopAll);
		set('Function_Stop', PyUtils.Function_Stop);
		set('Function_Continue', PyUtils.Function_Continue);
		set('pythonDebugMode', false);
		set('pythonDeprecatedWarnings', true);
		set('version', MainMenuState.psychEngineVersion.trim());
		set('modFolder', this.modFolder);

		// Song/Week shit
		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.SONG.bpm);
		set('scrollSpeed', PlayState.SONG.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('songName', PlayState.SONG.song);
		set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
		set('loadedSongName', Song.loadedSongName);
		set('loadedSongPath', Paths.formatToSongPath(Song.loadedSongName));
		set('chartPath', Song.chartPath);
		set('startedCountdown', false);
		set('curStage', PlayState.SONG.stage);

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);

		set('difficultyName', Difficulty.getString(false));
		set('difficultyPath', Difficulty.getFilePath());
		set('difficultyNameTranslation', Difficulty.getString(true));
		set('weekRaw', PlayState.storyWeek);
		set('week', WeekData.weeksList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);
		set('hasVocals', PlayState.SONG.needsVoices);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

        // PlayState-only variables
		if(game != null)
		@:privateAccess
		{
			var curSection:SwagSection = PlayState.SONG.notes[game.curSection];
			set('curSection', game.curSection);
			set('curBeat', game.curBeat);
			set('curStep', game.curStep);
			set('curDecBeat', game.curDecBeat);
			set('curDecStep', game.curDecStep);
	
			set('score', game.songScore);
			set('misses', game.songMisses);
			set('hits', game.songHits);
			set('combo', game.combo);
			set('deaths', PlayState.deathCounter);
	
			set('rating', game.ratingPercent);
			set('ratingName', game.ratingName);
			set('ratingFC', game.ratingFC);
			set('totalPlayed', game.totalPlayed);
			set('totalNotesHit', game.totalNotesHit);

			set('inGameOver', GameOverSubstate.instance != null);
			set('mustHitSection', curSection != null ? (curSection.mustHitSection == true) : false);
			set('altAnim', curSection != null ? (curSection.altAnim == true) : false);
			set('gfSection', curSection != null ? (curSection.gfSection == true) : false);

			set('healthGainMult', game.healthGain);
			set('healthLossMult', game.healthLoss);
	
			#if FLX_PITCH
			set('playbackRate', game.playbackRate);
			#else
			set('playbackRate', 1);
			#end
	
			set('guitarHeroSustains', game.guitarHeroSustains);
			set('instakillOnMiss', game.instakillOnMiss);
			set('botPlay', game.cpuControlled);
			set('practice', game.practiceMode);
	
			for (i in 0...4) {
				set('defaultPlayerStrumX' + i, 0);
				set('defaultPlayerStrumY' + i, 0);
				set('defaultOpponentStrumX' + i, 0);
				set('defaultOpponentStrumY' + i, 0);
			}
	
			// Default character data
			set('defaultBoyfriendX', game.BF_X);
			set('defaultBoyfriendY', game.BF_Y);
			set('defaultOpponentX', game.DAD_X);
			set('defaultOpponentY', game.DAD_Y);
			set('defaultGirlfriendX', game.GF_X);
			set('defaultGirlfriendY', game.GF_Y);

			set('boyfriendName', game.boyfriend != null ? game.boyfriend.curCharacter : PlayState.SONG.player1);
			set('dadName', game.dad != null ? game.dad.curCharacter : PlayState.SONG.player2);
			set('gfName', game.gf != null ? game.gf.curCharacter : PlayState.SONG.gfVersion);
		}

		// Other settings
		set('downscroll', ClientPrefs.data.downScroll);
		set('middlescroll', ClientPrefs.data.middleScroll);
		set('framerate', ClientPrefs.data.framerate);
		set('ghostTapping', ClientPrefs.data.ghostTapping);
		set('hideHud', ClientPrefs.data.hideHud);
		set('timeBarType', ClientPrefs.data.timeBarType);
		set('scoreZoom', ClientPrefs.data.scoreZoom);
		set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
		set('flashingLights', ClientPrefs.data.flashing);
		set('noteOffset', ClientPrefs.data.noteOffset);
		set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
		set('noResetButton', ClientPrefs.data.noReset);
		set('lowQuality', ClientPrefs.data.lowQuality);
		set('shadersEnabled', ClientPrefs.data.shaders);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);

		// Noteskin/Splash
		set('noteSkin', ClientPrefs.data.noteSkin);
		set('noteSkinPostfix', Note.getNoteSkinPostfix());
		set('splashSkin', ClientPrefs.data.splashSkin);
		set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());
		set('splashAlpha', ClientPrefs.data.splashAlpha);

		// build target (windows, mac, linux, etc.)
		set('buildTarget', PyUtils.getBuildTarget());
        set("getRunningScripts", function():Array<String> {
			var runningScripts:Array<String> = [];
			
			
			if (game != null && game.pythonArray != null) {
				for (script in game.pythonArray) {
					if (script != null) runningScripts.push(script.scriptName);
				}
                
			}
			return runningScripts;
        });
        addLocalCallback("setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
            if(exclusions == null) exclusions = [];
            if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
            game.setOnScripts(varName, arg, exclusions);
        });
        addLocalCallback("setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnHScript(varName, arg, exclusions);
		});
        addLocalCallback("setOnPythons", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
            if(exclusions == null) exclusions = [];
            if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
            game.setOnPythons(varName, arg, exclusions);
        });
        addLocalCallback("setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnLuas(varName, arg, exclusions);
		});
        addLocalCallback("callOnScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
		addLocalCallback("callOnLuas", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
		addLocalCallback("callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
        addLocalCallback("callOnPythons", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnPythons(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
		set("callPyScript", function(pyFile:String, funcName:String, ?args:Array<Dynamic> = null){
			if(args == null) args = [];
			var pyPath:String = findScript(pyFile);
			if(pyPath != null)
				for (pyInstance in game.pythonArray)
					if(pyInstance.scriptName == pyPath)
						return pyInstance.call(funcName, args);
			return null;
		});
		set("isRunning", function(pyFile:String, funcName:String, ?args:Array<Dynamic> = null){
			if(args == null) args = [];
			var pyPath:String = findScript(pyFile);
			if(pyPath != null)
				for (pyInstance in game.pythonArray)
					if(pyInstance.scriptName == pyPath)
						return true;
			#if HSCRIPT_ALLOWED
			var hscriptPath:String = findScript(scriptFile, '.hx');
			if(hscriptPath != null)
			{
				for (hscriptInstance in game.hscriptArray)
					if(hscriptInstance.origin == hscriptPath)
						return true;
			}
			#end
			return false;
		});
		set("setVar", function(varName:String, value:Dynamic) {
			MusicBeatState.getVariables().set(varName, ReflectionFunctions.parseSingleInstance(value));
			return value;
		});
		set("getVar", function(varName:String) {
			return MusicBeatState.getVariables().get(varName);
		});
		set("addPyScript", function(pyFile:String, ?ignoreAlreadyRunning:Bool = false){
			var pyPath:String = findScript(pyFile);
			if(pyPath != null)
			{
				if(!ignoreAlreadyRunning)
					for (pyInstance in game.pythonArray)
						if (pyInstance.scriptName == pyPath)
						{
							pythonTrace('addPyScript: The script "' + pyPath + '" is already running!');
							return;
						}
				new FunkinPython(pyPath);
				return;
			}
			pythonTrace("addPyScript: Script doesn't exist!", false, false, FlxColor.RED);
		});
		set("addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) {
			var luaPath:String = findScript(luaFile, '.lua');
			if(luaPath != null)
			{
				if(!ignoreAlreadyRunning)
					for (luaInstance in game.luaArray)
						if(luaInstance.scriptName == luaPath)
						{
							psychlua.FunkinLua.luaTrace('addLuaScript: The script "' + luaPath + '" is already running!');
							return;
						}

				new psychlua.FunkinLua(luaPath);
				return;
			}
			psychlua.FunkinLua.luaTrace("addLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
		});
		set("addHScript", function(scriptFile:String, ?ignoreAlreadyRunning:Bool = false) {
			#if HSCRIPT_ALLOWED
			var scriptPath:String = findScript(scriptFile, '.hx');
			if(scriptPath != null)
			{
				if(!ignoreAlreadyRunning)
					for (script in game.hscriptArray)
						if(script.origin == scriptPath)
						{
							psychlua.FunkinLua.luaTrace('addHScript: The script "' + scriptPath + '" is already running!');
							return;
						}

				PlayState.instance.initHScript(scriptPath);
				return;
			}
			psychlua.FunkinLua.luaTrace("addHScript: Script doesn't exist!", false, false, FlxColor.RED);
			#else
			psychlua.FunkinLua.luaTrace("addHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		set("removeLuaScript", function(luaFile:String) {
			var luaPath:String = findScript(luaFile, '.lua');
			if(luaPath != null)
			{
				var foundAny:Bool = false;
				for (luaInstance in game.luaArray)
				{
					if(luaInstance.scriptName == luaPath)
					{
						trace('Closing lua script $luaPath');
						luaInstance.stop();
						foundAny = true;
					}
				}
				if(foundAny) return true;
			}

			psychlua.FunkinLua.luaTrace('removeLuaScript: Script $luaFile isn\'t running!', false, false, FlxColor.RED);
			return false;
		});
		set("removePyScript", function(scriptFile:String) {
			#if PYTHON_ALLOWED
			var scriptPath:String = findScript(scriptFile);
			if (scriptPath != null)
			{
				var foundAny:Bool = false;
				for(pyInstance in game.pythonArray)
				{
					if(pyInstance.scriptName == scriptPath)
					{
						trace('Closing Python script $scriptPath');
						pyInstance.stop();
						foundAny = true;
					}
				}
				if(foundAny) return true;
			}
			pythonTrace('removePyScript: Script $scriptFile isn\'t running!', false, false, FlxColor.RED);
			return false;
			#else
			pythonTrace('removePyScript: Python is not supported on this platform!');
			#end
		});
		set("removeHScript", function(scriptFile:String) {
			#if HSCRIPT_ALLOWED
			var scriptPath:String = findScript(scriptFile, '.hx');
			if(scriptPath != null)
			{
				var foundAny:Bool = false;
				for (script in game.hscriptArray)
				{
					if(script.origin == scriptPath)
					{
						trace('Closing hscript $scriptPath');
						script.destroy();
						foundAny = true;
					}
				}
				if(foundAny) return true;
			}

			psychlua.FunkinLua.luaTrace('removeHScript: Script $scriptFile isn\'t running!', false, false, FlxColor.RED);
			return false;
			#else
			psychlua.FunkinLua.luaTrace("removeHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		set("loadSong", function(?name:String = null, ?difficultyNum:Int = -1) {
			if (name == null || name.length < 1)
				name = Song.loadedSongName;
			if(difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			var poop = Highscore.formatSong(name, difficultyNum);
			Song.loadFromJson(poop, name);
			PlayState.storyDifficulty = difficultyNum;
			FlxG.state.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			if(game != null && game.vocals != null)
			{
				game.vocals.pause();
				game.vocals.volume = 0;
			}
			FlxG.camera.followLerp = 0;
		});
		set("loadGraphics", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			var animated = gridX != 0 || gridY != 0;

			if(split.length > 1) {
				spr = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
			{
				spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
			}
		});
		set("loadFrames", function(variable:String, image:String, spriteType:String = 'auto') {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
			{
				PyUtils.loadFrames(spr, image, spriteType);
			}
		});
		set("loadMultipleFrames", function(variable:String, images:Array<String>) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null && images != null && images.length > 0)
			{
				spr.frames = Paths.getMultiAtlas(images);
			}
		});
		set("getObjectOrder", function(obj:String, ?group:String = null) {
			var leObj:FlxBasic = PyUtils.getObjectDirectly(obj);
			if(leObj != null)
			{
				if(group != null)
				{
					var groupOrArray:Dynamic = Reflect.getProperty(PyUtils.getTargetInstance(), group);
					if(groupOrArray != null)
					{
						switch(Type.typeof(groupOrArray))
						{
							case TClass(Array): //Is Array
								return groupOrArray.indexOf(leObj);
							default: //Is Group
								return Reflect.getProperty(groupOrArray, 'members').indexOf(leObj); //Has to use a Reflect here because of FlxTypedSpriteGroup
						}
					}
					else
					{
						pythonTrace('getObjectOrder: Group $group doesn\'t exist!', false, false, FlxColor.RED);
						return -1;
					}
				}
				var groupOrArray:Dynamic = CustomSubstate.instance != null ? CustomSubstate.instance : PyUtils.getTargetInstance();
				return groupOrArray.members.indexOf(leObj);
			}
			pythonTrace('getObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
			return -1;
		});
		set("setObjectOrder", function(obj:String, position:Int, ?group:String = null) {
			var leObj:FlxBasic = PyUtils.getObjectDirectly(obj);
			if(leObj != null)
			{
				if(group != null)
				{
					var groupOrArray:Dynamic = Reflect.getProperty(PyUtils.getTargetInstance(), group);
					if(groupOrArray != null)
					{
						switch(Type.typeof(groupOrArray))
						{
							case TClass(Array): //Is Array
								groupOrArray.remove(leObj);
								groupOrArray.insert(position, leObj);
							default: //Is Group
								groupOrArray.remove(leObj, true);
								groupOrArray.insert(position, leObj);
						}
					}
					else pythonTrace('setObjectOrder: Group $group doesn\'t exist!', false, false, FlxColor.RED);
				}
				else
				{
					var groupOrArray:Dynamic = CustomSubstate.instance != null ? CustomSubstate.instance : PyUtils.getTargetInstance();
					groupOrArray.remove(leObj, true);
					groupOrArray.insert(position, leObj);
				}
				return;
			}
			pythonTrace('setObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
		});
		set("startTween", function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			var penisExam:Dynamic = PyUtils.tweenPrepare(tag, vars);
			if(penisExam != null)
			{
				if(values != null)
				{
					var myOptions:PyTweenOptions = PyUtils.getPyTween(options);
					if(tag != null)
					{
						var variables = MusicBeatState.getVariables();
						var originalTag:String = 'tween_' + PyUtils.formatVariable(tag);
						variables.set(tag, FlxTween.tween(penisExam, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
	
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) game.callOnPythons(myOptions.onUpdate, [originalTag, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) game.callOnPythons(myOptions.onStart, [originalTag, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(tag);
								if(myOptions.onComplete != null) game.callOnPythons(myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					}
					else FlxTween.tween(penisExam, values, duration, myOptions != null ? {
						type: myOptions.type,
						ease: myOptions.ease,
						startDelay: myOptions.startDelay,
						loopDelay: myOptions.loopDelay,

						onUpdate: function(twn:FlxTween) {
							if(myOptions.onUpdate != null) game.callOnPythons(myOptions.onUpdate, [null, vars]);
						},
						onStart: function(twn:FlxTween) {
							if(myOptions.onStart != null) game.callOnPythons(myOptions.onStart, [null, vars]);
						},
						onComplete: function(twn:FlxTween) {
							if(myOptions.onComplete != null) game.callOnPythons(myOptions.onComplete, [null, vars]);
						}
					} : null);
				}
				else pythonTrace('startTween: No values on 2nd argument!', false, false, FlxColor.RED);
			}
			else pythonTrace('startTween: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			return null;
		});
		set("doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {x: value}, duration, ease, 'doTweenX');
		});
		set("doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {y: value}, duration, ease, 'doTweenY');
		});
		set("doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {angle: value}, duration, ease, 'doTweenAngle');
		});
		set("doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {alpha: value}, duration, ease, 'doTweenAlpha');
		});
		set("doTweenZoom", function(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			switch(camera.toLowerCase()) {
				case 'camgame' | 'game': camera = 'camGame';
				case 'camhud' | 'hud': camera = 'camHUD';
				case 'camother' | 'other': camera = 'camOther';
				default:
					var cam:FlxCamera = MusicBeatState.getVariables().get(camera);
					if (cam == null || !Std.isOfType(cam, FlxCamera)) camera = 'camGame';
			}
			return oldTweenFunction(tag, camera, {zoom: value}, duration, ease, 'doTweenZoom');
		});
		set("doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			var penisExam:Dynamic = PyUtils.tweenPrepare(tag, vars);
			if(penisExam != null) {
				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				
				if(tag != null)
				{
					var originalTag:String = tag;
					tag = PyUtils.formatVariable('tween_$tag');
					var variables = MusicBeatState.getVariables();
					variables.set(tag, FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: PyUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween)
						{
							variables.remove(tag);
							if (game != null) game.callOnPythons('onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				}
				else FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: PyUtils.getTweenEaseByString(ease)});
			}
			else pythonTrace('doTweenColor: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			return null;
		});
		set("noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {x: value}, duration, ease);
		});
		set("noteTweenY", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {y: value}, duration, ease);
		});
		set("noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {angle: value}, duration, ease);
		});
		set("noteTweenAlpha", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {alpha: value}, duration, ease);
		});
		set("noteTweenDirection", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {direction: value}, duration, ease);
		});
		set("mouseClicked", function(?button:String = 'left') {
			var click:Bool = FlxG.mouse.justPressed;
			switch(button.trim().toLowerCase())
			{
				case 'middle':
					click = FlxG.mouse.justPressedMiddle;
				case 'right':
					click = FlxG.mouse.justPressedRight;
			}
			return click;
		});
		set("mousePressed", function(?button:String = 'left') {
			var press:Bool = FlxG.mouse.pressed;
			switch(button.trim().toLowerCase())
			{
				case 'middle':
					press = FlxG.mouse.pressedMiddle;
				case 'right':
					press = FlxG.mouse.pressedRight;
			}
			return press;
		});
		set("mouseReleased", function(?button:String = 'left') {
			var released:Bool = FlxG.mouse.justReleased;
			switch(button.trim().toLowerCase())
			{
				case 'middle':
					released = FlxG.mouse.justReleasedMiddle;
				case 'right':
					released = FlxG.mouse.justReleasedRight;
			}
			return released;
		});
		set("cancelTween", function(tag:String) PyUtils.cancelTween(tag));
		set("runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			PyUtils.cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			
			var originalTag:String = tag;
			tag = PyUtils.formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer)
			{
				if(tmr.finished) variables.remove(tag);
				game.callOnPythons('onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
			return tag;
		});
		set("cancelTimer", function(tag:String) PyUtils.cancelTimer(tag));
		set("addScore", function(value:Int = 0) {
			game.songScore += value;
			game.RecalculateRating();
		});
		set("addMisses", function(value:Int = 0) {
			game.songMisses += value;
			game.RecalculateRating();
		});
		set("addHits", function(value:Int = 0) {
			game.songHits += value;
			game.RecalculateRating();
		});
		set("setScore", function(value:Int = 0) {
			game.songScore = value;
			game.RecalculateRating();
		});
		set("setMisses", function(value:Int = 0) {
			game.songMisses = value;
			game.RecalculateRating();
		});
		set("setHits", function(value:Int = 0) {
			game.songHits = value;
			game.RecalculateRating();
		});
		set("setHealth", function(value:Float = 1) game.health = value);
		set("addHealth", function(value:Float = 0) game.health += value);
		set("getHealth", function() return game.health);
		set("FlxColor", function(color:String) return FlxColor.fromString(color));
		set("getColorFromName", function(color:String) return FlxColor.fromString(color));
		set("getColorFromString", function(color:String) return FlxColor.fromString(color));
		set("getColorFromHex", function(color:String) return FlxColor.fromString('#$color'));

		set("addCharacterToList", function(name:String, type:String) {
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			game.addCharacterToList(name, charType);
		});
		set("precacheImage", function(name:String, ?allowGPU:Bool = true) {
			Paths.image(name, allowGPU);
		});
		set("precacheSound", function(name:String) {
			Paths.sound(name);
		});
		set("precacheMusic", function(name:String) {
			Paths.music(name);
		});
		set("triggerEvent", function(name:String, ?value1:String = '', ?value2:String = '') {
			game.triggerEvent(name, value1, value2, Conductor.songPosition);
			//trace('Triggered event: ' + name + ', ' + value1 + ', ' + value2);
			return true;
		});

		set("startCountdown", function() {
			game.startCountdown();
			return true;
		});
		set("endSong", function() {
			game.KillNotes();
			game.endSong();
			return true;
		});
		set("restartSong", function(?skipTransition:Bool = false) {
			game.persistentUpdate = false;
			FlxG.camera.followLerp = 0;
			PauseSubState.restartSong(skipTransition);
			return true;
		});
		set("exitSong", function(?skipTransition:Bool = false) {
			if(skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			if(PlayState.isStoryMode)
				MusicBeatState.switchState(new StoryMenuState());
			else
				MusicBeatState.switchState(new FreeplayState());

			#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			game.transitioning = true;
			FlxG.camera.followLerp = 0;
			Mods.loadTopMod();
			return true;
		});
		set("getSongPosition", function() {
			return Conductor.songPosition;
		});
		set("getCharacterX", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return game.dadGroup.x;
				case 'gf' | 'girlfriend':
					return game.gfGroup.x;
				default:
					return game.boyfriendGroup.x;
			}
		});
		set("setCharacterX", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					game.dadGroup.x = value;
				case 'gf' | 'girlfriend':
					game.gfGroup.x = value;
				default:
					game.boyfriendGroup.x = value;
			}
		});
		set("getCharacterY", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return game.dadGroup.y;
				case 'gf' | 'girlfriend':
					return game.gfGroup.y;
				default:
					return game.boyfriendGroup.y;
			}
		});
		set("setCharacterY", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					game.dadGroup.y = value;
				case 'gf' | 'girlfriend':
					game.gfGroup.y = value;
				default:
					game.boyfriendGroup.y = value;
			}
		});

		set("cameraSetTarget", function(target:String) {
			switch(target.trim().toLowerCase())
			{
				case 'gf', 'girlfriend':
					game.moveCameraToGirlfriend();
				case 'dad', 'opponent':
					game.moveCamera(true);
				default:
					game.moveCamera(false);
			}
		});
		set("setCameraScroll", function(x:Float, y:Float) FlxG.camera.scroll.set(x - FlxG.width/2, y - FlxG.height/2));
		set("setCameraFollowPoint", function(x:Float, y:Float) game.camFollow.setPosition(x, y));
		set("addCameraScroll", function(?x:Float = 0, ?y:Float = 0) FlxG.camera.scroll.add(x, y));
		set("addCameraFollowPoint", function(?x:Float = 0, ?y:Float = 0) {
				game.camFollow.x += x;
			game.camFollow.y += y;
		});
		set("getCameraScrollX", () -> FlxG.camera.scroll.x + FlxG.width/2);
		set("getCameraScrollY", () -> FlxG.camera.scroll.y + FlxG.height/2);
		set("getCameraFollowX", () -> game.camFollow.x);
		set("getCameraFollowY", () -> game.camFollow.y);
		set("cameraShake", function(camera:String, intensity:Float, duration:Float) {
			PyUtils.cameraFromString(camera).shake(intensity, duration);
		});
		set("cameraFlash", function(camera:String, color:String, duration:Float,forced:Bool) {
			PyUtils.cameraFromString(camera).flash(CoolUtil.colorFromString(color), duration, null, forced);
		});
		set("cameraFade", function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) {
			PyUtils.cameraFromString(camera).fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced);
		});
		set("setRatingPercent", function(value:Float) {
			game.ratingPercent = value;
			game.setOnScripts('rating', game.ratingPercent);
		});
		set( "setRatingName", function(value:String) {
			game.ratingName = value;
			game.setOnScripts('ratingName', game.ratingName);
		});
		set( "setRatingFC", function(value:String) {
			game.ratingFC = value;
			game.setOnScripts('ratingFC', game.ratingFC);
		});
		set("updateScoreText", function() game.updateScoreText());
		set("getMouseX", function(?camera:String = 'game') {
			var cam:FlxCamera = PyUtils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		set("getMouseY", function(?camera:String = 'game') {
			var cam:FlxCamera = PyUtils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});
		set("getMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getMidpoint().x;

			return 0;
		});
		set("getMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getMidpoint().y;

			return 0;
		});
		set("getGraphicMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().x;

			return 0;
		});
		set("getGraphicMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().y;

			return 0;
		});
		set("getScreenPositionX", function(variable:String, ?camera:String = 'game') {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getScreenPosition(PyUtils.cameraFromString(camera)).x;

			return 0;
		});
		set("getScreenPositionY", function(variable:String, ?camera:String = 'game') {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getScreenPosition(PyUtils.cameraFromString(camera)).y;

			return 0;
		});
		set("characterDance", function(character:String) {
			switch(character.toLowerCase()) {
				case 'dad': game.dad.dance();
				case 'gf' | 'girlfriend': if(game.gf != null) game.gf.dance();
				default: game.boyfriend.dance();
			}
		});
		set("makePySprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			PyUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
			{
				leSprite.loadGraphic(Paths.image(image));
			}
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		set("makeAnimatedPySprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			PyUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			if(image != null && image.length > 0)
			{
				PyUtils.loadFrames(leSprite, image, spriteType);
			}
			MusicBeatState.getVariables().set(tag, leSprite);
		});
		set("makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = PyUtils.getObjectDirectly(obj);
			if(spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		set("addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:FlxSprite = cast PyUtils.getObjectDirectly(obj);
			if(obj != null && obj.animation != null)
			{
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if(obj.animation.curAnim == null)
				{
					var dyn:Dynamic = cast obj;
					if(dyn.playAnim != null) dyn.playAnim(name, true);
					else dyn.animation.play(name, true);
				}
				return true;
			}
			return false;
		});
		set("addAnimation", function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true) {
			return PyUtils.addAnimByIndices(obj, name, null, frames, framerate, loop);
		});
		set("addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false) {
			return PyUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});
		set("playAnim", function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
		{
			var obj:Dynamic = PyUtils.getObjectDirectly(obj);
			if(obj.playAnim != null)
			{
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			}
			else
			{
				if(obj.anim != null) obj.anim.play(name, forced, reverse, startFrame); //FlxAnimate
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		set("addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = PyUtils.getObjectDirectly(obj);
			if(obj != null && obj.addOffset != null)
			{
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});
		set("setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			if(game.getPyObject(obj) != null) {
				game.getPyObject(obj).scrollFactor.set(scrollX, scrollY);
				return;
			}

			var object:FlxObject = Reflect.getProperty(PyUtils.getTargetInstance(), obj);
			if(object != null) {
				object.scrollFactor.set(scrollX, scrollY);
			}
		});
		set("addPySprite", function(tag:String, ?inFront:Bool = false) {
			var mySprite:FlxSprite = MusicBeatState.getVariables().get(tag);
			if(mySprite == null) return;

			var instance = PyUtils.getTargetInstance();
			if(inFront)
				instance.add(mySprite);
			else
			{
				if(PlayState.instance == null || !PlayState.instance.isDead)
					instance.insert(instance.members.indexOf(PyUtils.getLowestCharacterGroup()), mySprite);
				else
					GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), mySprite);
			}
		});
		set("setGraphicSize", function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			if(game.getPyObject(obj)!=null) {
				var shit:FlxSprite = game.getPyObject(obj);
				shit.setGraphicSize(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				poop = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			pythonTrace('setGraphicSize: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		set("scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			if(game.getPyObject(obj)!=null) {
				var shit:FlxSprite = game.getPyObject(obj);
				shit.scale.set(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				poop = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			pythonTrace('scaleObject: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		set("updateHitbox", function(obj:String) {
			if(game.getPyObject(obj)!=null) {
				var shit:FlxSprite = game.getPyObject(obj);
				shit.updateHitbox();
				return;
			}
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				poop = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(poop != null) {
				poop.updateHitbox();
				return;
			}
			pythonTrace('updateHitbox: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		set("removeLuaSprite", function(tag:String, destroy:Bool = true, ?group:String = null) {
			var obj:FlxSprite = PyUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null)
				return;
			
			var groupObj:Dynamic = null;
			if(group == null) groupObj = PyUtils.getTargetInstance();
			else groupObj = PyUtils.getObjectDirectly(group);

			groupObj.remove(obj, true);
			if(destroy)
			{
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});
		set("pySpriteExists", function(tag:String) {
			var obj:FlxSprite = MusicBeatState.getVariables().get(tag);
			return (obj != null && (Std.isOfType(obj, ModchartSprite) || Std.isOfType(obj, ModchartAnimateSprite)));
		});
		set("pyTextExists", function(tag:String) {
			var obj:FlxText = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, FlxText));
		});
		set("pySoundExists", function(tag:String) {
			var obj:FlxSound = MusicBeatState.getVariables().get('sound_$tag');
			return (obj != null && Std.isOfType(obj, FlxSound));
		});
		set("setHealthBarColors", function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			game.healthBar.setColors(left_color, right_color);
		});
		set("setTimeBarColors", function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			game.timeBar.setColors(left_color, right_color);
		});
		set("setObjectCamera", function(obj:String, camera:String = 'game') {
			var real:FlxBasic = game.getLuaObject(obj);
			if(real != null) {
				real.cameras = [PyUtils.cameraFromString(camera)];
				return true;
			}

			var split:Array<String> = obj.split('.');
			var object:FlxBasic = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				object = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(object != null) {
				object.cameras = [PyUtils.cameraFromString(camera)];
				return true;
			}
			pythonTrace("setObjectCamera: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		set("screenCenter", function(obj:String, pos:String = 'xy') {
			var spr:FlxObject = game.getPyObject(obj);

			if(spr==null){
				var split:Array<String> = obj.split('.');
				spr = PyUtils.getObjectDirectly(split[0]);
				if(split.length > 1) {
					spr = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
				}
			}

			if(spr != null)
			{
				switch(pos.trim().toLowerCase())
				{
					case 'x':
						spr.screenCenter(X);
						return;
					case 'y':
						spr.screenCenter(Y);
						return;
					default:
						spr.screenCenter(XY);
						return;
				}
			}
			pythonTrace("screenCenter: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});

		set("setBlendMode", function(obj:String, blend:String = '') {
			var real:FlxSprite = game.getPyObject(obj);
			if(real != null) {
				real.blend = PyUtils.blendModeFromString(blend);
				return true;
			}

			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null) {
				spr.blend = PyUtils.blendModeFromString(blend);
				return true;
			}
			pythonTrace("setBlendMode: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		set("objectsOverlap", function(obj1:String, obj2:String) {
			var namesArray:Array<String> = [obj1, obj2];
			var objectsArray:Array<FlxBasic> = [];
			for (i in 0...namesArray.length)
			{
				var real:FlxBasic = game.getPyObject(namesArray[i]);
				if(real != null)
					objectsArray.push(real);
				else
					objectsArray.push(Reflect.getProperty(PyUtils.getTargetInstance(), namesArray[i]));
			}
			return (!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]));
		});
		set("getPixelColor", function(obj:String, x:Int, y:Int) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = PyUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = PyUtils.getVarInArray(PyUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		set("startDialogue", function(dialogueFile:String, ?music:String = null) {
			var path:String;
			var songPath:String = Paths.formatToSongPath(Song.loadedSongName);
			#if TRANSLATIONS_ALLOWED
			path = Paths.getPath('data/$songPath/${dialogueFile}_${ClientPrefs.data.language}.json', TEXT);
			#if MODS_ALLOWED
			if(!FileSystem.exists(path))
			#else
			if(!Assets.exists(path, TEXT))
			#end
			#end
				path = Paths.getPath('data/$songPath/$dialogueFile.json', TEXT);

			pythonTrace('startDialogue: Trying to load dialogue: ' + path);

			#if MODS_ALLOWED
			if(FileSystem.exists(path))
			#else
			if(Assets.exists(path, TEXT))
			#end
			{
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if(shit.dialogue.length > 0)
				{
					game.startDialogue(shit, music);
					pythonTrace('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);
					return true;
				}
				else pythonTrace('startDialogue: Your dialogue file is badly formatted!', false, false, FlxColor.RED);
			}
			else
			{
				pythonTrace('startDialogue: Dialogue file not found', false, false, FlxColor.RED);
				if(game.endingSong)
					game.endSong();
				else
					game.startCountdown();
			}
			return false;
		});
		set("startVideo", function(videoFile:String, ?canSkip:Bool = true, ?forMidSong:Bool = false, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true) {
			#if VIDEOS_ALLOWED
			if(FileSystem.exists(Paths.video(videoFile)))
			{
				if(game.videoCutscene != null)
				{
					game.remove(game.videoCutscene);
					game.videoCutscene.destroy();
				}
				game.videoCutscene = game.startVideo(videoFile, forMidSong, canSkip, shouldLoop, playOnLoad);
				return true;
			}
			else
			{
				pythonTrace('startVideo: Video file not found: ' + videoFile, false, false, FlxColor.RED);
			}
			return false;

			#else
			PlayState.instance.inCutscene = true;
			new FlxTimer().start(0.1, function(tmr:FlxTimer)
			{
				PlayState.instance.inCutscene = false;
				if(game.endingSong)
					game.endSong();
				else
					game.startCountdown();
			});
			return true;
			#end
		});
		set("playMusic", function(sound:String, ?volume:Float = 1, ?loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		set("playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false) {
			if(tag != null && tag.length > 0)
			{
				var originalTag:String = tag;
				tag = PyUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd = variables.get(tag);
				if(oldSnd != null)
				{
					oldSnd.stop();
					oldSnd.destroy();
				}

				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, function()
				{
					if(!loop) variables.remove(tag);
					if(game != null) game.callOnPythons('onSoundFinished', [originalTag]);
				}));
				return tag;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
			return null;
		});
		set("stopSound", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.stop();
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var snd:FlxSound = variables.get(tag);
				if(snd != null)
				{
					snd.stop();
					variables.remove(tag);
				}
			}
		});
		set("pauseSound", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.pause();
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.pause();
			}
		});
		set("resumeSound", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.play();
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.play();
			}
		});
		set("soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null)
					snd.fadeIn(duration, fromValue, toValue);
			}
		});
		set("soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.fadeOut(duration, toValue);
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null)
					snd.fadeOut(duration, toValue);
			}
		});
		set("soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null && FlxG.sound.music.fadeTween != null)
					FlxG.sound.music.fadeTween.cancel();
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null && snd.fadeTween != null)
					snd.fadeTween.cancel();
			}
		});
		set("getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					return FlxG.sound.music.volume;
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) return snd.volume;
			}
			return 0;
		});
		set("setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1)
			{
				tag = PyUtils.formatVariable('sound_$tag');
				if(FlxG.sound.music != null)
				{
					FlxG.sound.music.volume = value;
					return;
				}
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.volume = value;
			}
		});
		set("getSoundTime", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				return FlxG.sound.music != null ? FlxG.sound.music.time : 0;
			}
			tag = PyUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.time : 0;
		});
		set("setSoundTime", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
				{
					FlxG.sound.music.time = value;
					return;
				}
			}
			else
			{
				tag = PyUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.time = value;
			}
		});
		set("getSoundPitch", function(tag:String) {
			#if FLX_PITCH
			tag = PyUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.pitch : 1;
			#else
			pythonTrace("getSoundPitch: Sound Pitch is not supported on this platform!", false, false, FlxColor.RED);
			return 1;
			#end
		});
		set("setSoundPitch", function(tag:String, value:Float, ?doPause:Bool = false) {
			#if FLX_PITCH
			tag = PyUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			if(snd != null)
			{
				var wasResumed:Bool = snd.playing;
				if (doPause) snd.pause();
				snd.pitch = value;
				if (doPause && wasResumed) snd.play();
			}
			
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
				{
					var wasResumed:Bool = FlxG.sound.music.playing;
					if (doPause) FlxG.sound.music.pause();
					FlxG.sound.music.pitch = value;
					if (doPause && wasResumed) FlxG.sound.music.play();
					return;
				}
			}
			else
			{
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null)
				{
					var wasResumed:Bool = snd.playing;
					if (doPause) snd.pause();
					snd.pitch = value;
					if (doPause && wasResumed) snd.play();
				}
			}
			#else
			pythonTrace("setSoundPitch: Sound Pitch is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		addLocalCallback("getModSetting", function(saveTag:String, ?modName:String = null) {
			#if MODS_ALLOWED
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					FunkinPython.pythonTrace('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', false, false, FlxColor.RED);
					return null;
				}
				modName = this.modFolder;
			}
			return PyUtils.getModSetting(saveTag, modName);
			#else
			pythonTrace("getModSetting: Mods are disabled in this build!", false, false, FlxColor.RED);
			#end
		});
		// Recommended to use debugPrint()
		set("finalDebug", function(text:Dynamic = '', color:String = 'WHITE') PlayState.instance.addTextToDebug(text, CoolUtil.colorFromString(color)));
		PyRun.simpleString("
def debugPrint(text = '', color:str = 'WHITE'):
	finalDebug(str(text), color)
		");
		addLocalCallback("close", function() {
			closed = true;
			trace('Closing script $scriptName');
			return closed;
		});
		#if DISCORD_ALLOWED DiscordClient.addPyCallbacks(this); #end
		#if ACHIEVEMENTS_ALLOWED Achievements.addPyCallbacks(this); #end
		#if TRANSLATIONS_ALLOWED Language.addPyCallbacks(this); #end
		HScript.implement(this);
		#if flxanimate FlxAnimateFunctions.implement(this); #end
		ReflectionFunctions.implement(this);
		TextFunctions.implement(this);
		ExtraFunctions.implement(this);
		CustomSubstate.implement(this);
		ShaderFunctions.implement(this);
		// DeprecatedFunctions.implement(this);

		try {
			if (FileSystem.exists(scriptName)) 
			{
				var pyCode:String = sys.io.File.getContent(scriptName);
				
				
				pyCode = StringTools.replace(pyCode, "\t", "    ");
				pyCode = StringTools.replace(pyCode, "\r\n", "\n");
				
				// Generating a unique and safe name for this script's dictionary
				var safeName:String = scriptFile.split("/").pop().split("\\").pop().split(".")[0];
				safeName = ~/[^a-zA-Z0-9_]/g.replace(safeName, ""); 

				// Creating a Python wrapper that will execute the file's code in an isolated context
				var base64Code:String = haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(pyCode));

				var isolatedWrapper:String = "
import sys
import gc
import base64
gc.disable()

# NO CHEATERS!!!
dangerous_modules = ['os', 'subprocess', 'shutil', 'ctypes', 'importlib', 'nt', 'posix', 'pathlib', 'io']
for mod in dangerous_modules:
    if mod in sys.modules: del sys.modules[mod]
    sys.modules[mod] = None

if 'python_mods' not in globals():
    global python_mods
    python_mods = {}


if '" + safeName + "' not in python_mods:
    python_mods['" + safeName + "'] = dict(globals())
    if 'python_mods' in python_mods['" + safeName + "']:
        del python_mods['" + safeName + "']['python_mods']

raw_user_code = base64.b64decode('" + base64Code + "').decode('utf-8')
exec(raw_user_code, python_mods['" + safeName + "'])
";



				
				this.result = hxpy.PyRun.simpleString((cast isolatedWrapper:cpp.ConstCharStar));
				trace(this.result);
				if (!this.result) 
				{
					trace("Python script loaded successfully via hxpy (Isolated): " + scriptName);
					
					call('onCreate', []);
				} 
				else 
				{
					var filename:String = scriptFile.split("/").pop().split("\\").pop();
					states.PlayState.instance.addTextToDebug(filename + ": [Python Syntax Error]", FlxColor.RED);
					trace("[HXPY ERROR] Syntax or Initialization error in: " + scriptName);
				}
			} 
			else 
			{
				states.PlayState.instance.addTextToDebug(scriptFile.split("/").pop() + ": File not found", FlxColor.RED);
			}
		} 
		catch (e:haxe.Exception) 
		{
			var filename:String = scriptFile.split("/").pop().split("\\").pop();
			states.PlayState.instance.addTextToDebug(filename + ": [Critical Haxe Exception]: " + e.message, FlxColor.RED);
			trace("[HXPY CRITICAL EXCEPTION] " + e.message);
		}

    }
	public function stop()
	{
		if (closed) return;

		var safeNameArray:Array<String> = scriptFile.split("/").pop().split("\\").pop().split(".");
		var rawSafeName:String = safeNameArray[0];
		rawSafeName = ~/[^a-zA-Z0-9_]/g.replace(rawSafeName, "");

		var cleanMemoryCode:String = "
if 'python_mods' in globals() and '" + rawSafeName + "' in python_mods:
	python_mods['" + rawSafeName + "'].clear()
	del python_mods['" + rawSafeName + "']
import gc
gc.collect()
";
		hxpy.PyRun.simpleString((cast cleanMemoryCode:cpp.ConstCharStar));

		if (functionRegistry != null) {
			functionRegistry.clear();
		}

		closed = true;
		
		#if HSCRIPT_ALLOWED
		if (hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
	}



    public function addLocalCallback(name:String, myFunction:Dynamic)
    {
        // 1. Save to the local map for compatibility if other engine systems query it.
        callbacks.set(name, myFunction);

		// 2. Unlike Lua, in Hython we IMMEDIATELY register the actual function in the Python namespace!
        if (Py.isInitialized()) {
            set(name, myFunction);
        }
    }
	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end
	@:inline 
	public static function convertHaxeToPy(value:Dynamic):cpp.RawPointer<hxpy.PyObject> {
		if (value == null) {
			untyped __cpp__("Py_INCREF(Py_None)");
			return Py.NONE;
		}

		// Type.typeof() работает в разы быстрее на C++, так как не вызывает dynamic_cast
		switch (Type.typeof(value)) {
			case TInt:
				var intVal:Int = cast value;
				return untyped __cpp__("PyLong_FromLong({0})", intVal);
				
			case TFloat:
				var floatVal:Float = cast value;
				return untyped __cpp__("PyFloat_FromDouble({0})", floatVal);
				
			case TBool:
				var boolVal:Bool = cast value;
				var res = boolVal ? Py.TRUE : Py.FALSE;
				untyped __cpp__("Py_INCREF({0})", res);
				return res;
				
			case TClass(String):
				var strVal:String = cast value; 
				return untyped __cpp__("PyUnicode_FromStringAndSize({0}.__s, {0}.length)", strVal);
				
			default:
				untyped __cpp__("Py_INCREF(Py_None)");
				return Py.NONE;
		}
	}

	@:void
	private static function universalCallbackBridge(self:cpp.RawPointer<hxpy.PyObject>, args:cpp.RawPointer<hxpy.PyObject>):cpp.RawPointer<hxpy.PyObject> {
		var funcId:Int = cast untyped __cpp__("PyLong_AsLong({0})", self);
		var haxeFunc:Dynamic = functionRegistry.get(funcId);
		
		if (haxeFunc == null) {
			untyped __cpp__("PyErr_SetString(PyExc_RuntimeError, \"Haxe function not found\")");
			return Py.NONE;
		}

		var argsCount:Int = cast untyped __cpp__("PyTuple_Size({0})", args);
		var haxeArgs:Array<Dynamic> = [];

		for (i in 0...argsCount) {
			var pyArg:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyTuple_GetItem({0}, {1})", args, i);
			
			var val:Dynamic = null;
			if (untyped __cpp__("PyLong_Check({0})", pyArg))       val = cast untyped __cpp__("PyLong_AsLong({0})", pyArg);
			else if (untyped __cpp__("PyFloat_Check({0})", pyArg)) val = cast untyped __cpp__("PyFloat_AsDouble({0})", pyArg);
			else if (untyped __cpp__("PyUnicode_Check({0})", pyArg)) {
				val = untyped __cpp__("String(PyUnicode_AsUTF8({0}))", pyArg);
			}
			else if (pyArg == Py.TRUE)  val = true;
			else if (pyArg == Py.FALSE) val = false;
			
			haxeArgs.push(val);
		}

		var result:Dynamic = Reflect.callMethod(null, haxeFunc, haxeArgs);
		return convertHaxeToPy(result);
	}

	public function set(variable:String, value:Dynamic):Void {
		var mainModule:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyImport_AddModule(\"__main__\")");
		var mainDict:cpp.RawPointer<hxpy.PyObject> = PyModule.getDict(mainModule);
		var pyObject:cpp.RawPointer<hxpy.PyObject> = null;

		if (Reflect.isFunction(value)) {
			var id:Int = nextFunctionId++;
			functionRegistry.set(id, value);
			
			var pyId:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyLong_FromLong({0})", id);

			// The stable flat C++ lambda for MSVC remains untouched
			pyObject = untyped __cpp__("[] (const char* name, PyObject* idObj) -> PyObject* {
				PyMethodDef* def = new PyMethodDef();
				#ifdef _MSC_VER
				def->ml_name = _strdup(name);
				#else
				def->ml_name = strdup(name);
				#endif
				def->ml_meth = (PyCFunction)psychpython::FunkinPython_obj::universalCallbackBridge;
				def->ml_flags = METH_VARARGS;
				def->ml_doc = NULL;
				return PyCFunction_NewEx(def, idObj, NULL);
			}({0}.__s, {1})", variable, pyId);
			
			untyped __cpp__("Py_DECREF({0})", pyId);
		}
		else {
			pyObject = convertHaxeToPy(value);
			if (pyObject == Py.TRUE || pyObject == Py.FALSE || pyObject == Py.NONE) {
				untyped __cpp__("Py_INCREF({0})", pyObject);
			}
		}

		if (pyObject != null) {
			var cVar:cpp.ConstCharStar = cast variable;
			// 1. First, writing the variable to the global dictionary, as before
			untyped __cpp__("PyDict_SetItemString({0}, {1}, {2})", mainDict, cVar, pyObject);
			untyped __cpp__("Py_DECREF({0})", pyObject);

			// 2. SYNCHRONIZATION WITH CONTEXT: Copy this variable to the script's private dictionary
			// This ensures that the variable will always be up-to-date within an isolated exec()
			var safeNameArray:Array<String> = scriptFile.split("/").pop().split("\\").pop().split(".");
			var rawSafeName:String = safeNameArray[0];
			rawSafeName = ~/[^a-zA-Z0-9_]/g.replace(rawSafeName, "");

			var syncCode:String = "
if 'python_mods' in globals() and '" + rawSafeName + "' in python_mods:
    python_mods['" + rawSafeName + "']['" + variable + "'] = globals()['" + variable + "']
";
			hxpy.PyRun.simpleString((cast syncCode:cpp.ConstCharStar));
		}
	}

	public static function convertPyToHaxe(pyObj:cpp.RawPointer<hxpy.PyObject>):Dynamic {
		if (pyObj == null || pyObj == Py.NONE) {
			return null;
		}

		// 1. Проверяем на Boolean (в C-API булевы типы — это подвид Long)
		if (untyped __cpp__("PyBool_Check({0})", pyObj) == 1) {
			return (pyObj == Py.TRUE);
		}

		// 2. Проверяем на целое число (Integer / Long)
		if (untyped __cpp__("PyLong_Check({0})", pyObj) == 1) {
			var result:Int = untyped __cpp__("(int)PyLong_AsLong({0})", pyObj);
			return result;
		}

		// 3. Проверяем на число с плавающей точкой (Float)
		if (untyped __cpp__("PyFloat_Check({0})", pyObj) == 1) {
			var result:Float = untyped __cpp__("PyFloat_AsDouble({0})", pyObj);
			return result;
		}

		// 4. Проверяем на строку (Unicode в Python 3)
		if (untyped __cpp__("PyUnicode_Check({0})", pyObj) == 1) {
			// Вытаскиваем сырую C-строку в UTF-8
			var cStr:cpp.ConstCharStar = untyped __cpp__("PyUnicode_AsUTF8({0})", pyObj);
			if (cStr != null) {
				// Конвертируем C-строку обратно в родной String фреймворка Haxe
				return Std.string(cStr);
			}
		}

		// 5. Если прилетело что-то сложное (список, словарь или кастомный класс Python)
		// Пока возвращаем null или константу, чтобы не ломать логику движка
		return null;
	}

	public function call(funcName:String, args:Array<Dynamic>):Dynamic {
		if (closed) return PyUtils.Function_Continue;
		lastCalledScript = this;

		try {
			// 1. Быстрое извлечение имени скрипта на чистых C++ индексах (без тяжелых RegEx и split)
			// Это спасает игру от микрофризов на кадрах onUpdate
			var lastSlash:Int = scriptFile.lastIndexOf("/");
			if (lastSlash == -1) lastSlash = scriptFile.lastIndexOf("\\");
			var lastDot:Int = scriptFile.lastIndexOf(".");
			var rawSafeName:String = (lastDot > lastSlash) ? scriptFile.substring(lastSlash + 1, lastDot) : scriptFile.substring(lastSlash + 1);

			// 2. Достаем модуль/словарь python_mods из __main__ средствами C-API
			var mainModule:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyImport_AddModule(\"__main__\")");
			var mainDict:cpp.RawPointer<hxpy.PyObject> = PyModule.getDict(mainModule);
			
			// Ищем python_mods
			var pyMods:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyDict_GetItemString({0}, \"python_mods\")", mainDict);
			if (pyMods == null) return PyUtils.Function_Continue;

			// Достаем контекст нашего скрипта: python_mods['имя_скрипта']
			var scriptCtxLocal:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyDict_GetItemString({0}, {1}.__s)", pyMods, rawSafeName);
			if (scriptCtxLocal == null) return PyUtils.Function_Continue;

			// Ищем саму функцию внутри контекста скрипта
			var pyFunc:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyDict_GetItemString({0}, {1}.__s)", scriptCtxLocal, funcName);
			
			// Проверяем, существует ли она и можно ли её вызвать (callable)
			if (pyFunc != null && untyped __cpp__("PyCallable_Check({0})", pyFunc) == 1) {
				
				// 3. Собираем аргументы в PyTuple (родной кортеж Python)
				var len:Int = (args != null) ? args.length : 0;

				// ОПТИМИЗАЦИЯ: Изначально ставим указатель в null. 
				// Если аргументов нет (onBeatHit, onStepHit), пустой PyTuple создаваться НЕ БУДЕТ!
				var pyArgs:cpp.RawPointer<hxpy.PyObject> = null; 

				if (len > 0) {
					// Создаем кортеж только тогда, когда реально есть что передавать (например, в opponentNoteHit)
					pyArgs = untyped __cpp__("PyTuple_New({0})", len);
					
					var localArgs = args; // Кэш для оптимизатора Haxe 4.3.2
					for (i in 0...len) {
						var pyArg:cpp.RawPointer<hxpy.PyObject> = convertHaxeToPy(localArgs[i]);
						
						// ЗАЩИТА СИНГЛТОНОВ: Если конвертер вернул None, True или False, 
						// нужно сделать INCREF, потому что PyTuple_SetItem заберет эту ссылку себе!
						if (pyArg == Py.NONE || pyArg == Py.TRUE || pyArg == Py.FALSE) {
							untyped __cpp__("Py_INCREF({0})", pyArg);
						}
						
						untyped __cpp__("PyTuple_SetItem({0}, {1}, {2})", pyArgs, i, pyArg);
					}
				}

				// 4. ВЫЗЫВАЕМ ФУНКЦИЮ НАПРЯМУЮ В ПАМЯТИ
				var pyResult:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyObject_CallObject({0}, {1})", pyFunc, pyArgs);
				
				// Безопасно чистим кортеж аргументов, только если он создавался
				if (pyArgs != null) {
					untyped __cpp__("Py_DECREF({0})", pyArgs); 
				}

				if (pyResult != null) {
					// 5. Конвертируем результат обратно в Haxe!
					var haxeResult:Dynamic = convertPyToHaxe(pyResult); 
					
					// ИСПРАВЛЕНО: Безопасная очистка результата.
					// Если функция вернула None, True или False, их НЕЛЬЗЯ декрефить, иначе со временем игра упадет!
					if (pyResult != Py.NONE && pyResult != Py.TRUE && pyResult != Py.FALSE) {
						untyped __cpp__("Py_DECREF({0})", pyResult);
					}
					
					return haxeResult;
				} else {
					untyped __cpp__("PyErr_Print()"); // Выводим ошибку Python в консоль
				}
			}
			
			return PyUtils.Function_Continue;
		} 
		catch(e:haxe.Exception) {
			pythonTrace("RUNTIME: Error in function '" + funcName + "' (script: " + scriptName + "): " + e.message, false, false, flixel.util.FlxColor.RED);
		}

		return PyUtils.Function_Continue;
	}


	public function findScript(scriptFile:String, ext:String = '.py'):String
	{
		
		if(!scriptFile.endsWith(ext)) scriptFile += ext;

		var path:String = Paths.getPath(scriptFile, TEXT);

		#if MODS_ALLOWED
		var modPath:String = Paths.mods(scriptFile);

		if(FileSystem.exists(modPath)) {
			return modPath;
		}
		else if(FileSystem.exists(path)) {
			return path;
		}
		else if(FileSystem.exists(scriptFile)) {
			return scriptFile;
		}
		#else
		if(Assets.exists(path, TEXT)) {
			return path;
		}
		else if(Assets.exists(scriptFile, TEXT)) {
			return scriptFile;
		}
		#end

		return null;
	}
	public function initPyShader(name:String)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if(runtimeShaders.exists(name))
		{
			var shaderData:Array<String> = runtimeShaders.get(name);
			if(shaderData != null && (shaderData[0] != null || shaderData[1] != null))
			{
				pythonTrace('Shader $name was already initialized!');
				return true;
			}
		}

		var foldersToCheck:Array<String> = [Paths.getSharedPath('shaders/')];
		#if MODS_ALLOWED
		foldersToCheck.push(Paths.mods('shaders/'));
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if(FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		pythonTrace('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
		#else
		pythonTrace('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
		#end
		return false;
	}
	public static function pythonTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		if(ignoreCheck || getBool('pythonDebugMode')) {
			if(deprecated && !getBool('pythonDeprecatedWarnings')) {
				return;
			}
			PlayState.instance.addTextToDebug("[PYTHON] " + text, color);
		}
	}

    public static function getBool(variable:String):Bool 
    {
        if (lastCalledScript == null || lastCalledScript.closed) return false;

        var mainModule:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyImport_AddModule(\"__main__\")");
        var mainDict:cpp.RawPointer<hxpy.PyObject> = hxpy.PyModule.getDict(mainModule);
        
        var pyObj:cpp.RawPointer<hxpy.PyObject> = untyped __cpp__("PyDict_GetItemString({0}, {1}.__s)", mainDict, variable);
        
        if (pyObj == null) {
            return false;
        }

        return (pyObj == hxpy.Py.TRUE);
    }


	function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String)
	{
		var target:Dynamic = PyUtils.tweenPrepare(tag, vars);
		var variables = MusicBeatState.getVariables();
		if(target != null)
		{
			if(tag != null)
			{
				var originalTag:String = tag;
				tag = PyUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(target, tweenValue, duration, {ease: PyUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween)
					{
						variables.remove(tag);
						if(PlayState.instance != null) PlayState.instance.callOnPythons('onTweenCompleted', [originalTag, vars]);
					}
				}));
			}
			else FlxTween.tween(target, tweenValue, duration, {ease: PyUtils.getTweenEaseByString(ease)});
			return tag;
		}
		else pythonTrace('$funcName: Couldnt find object: $vars', false, false, FlxColor.RED);
		return null;
	}
	function noteTweenFunction(tag:String, note:Int, data:Dynamic, duration:Float, ease:String)
	{
		if(PlayState.instance == null) return null;

		var strumNote:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];
		if(strumNote == null) return null;

		if(tag != null)
		{
			var originalTag:String = tag;
			tag = PyUtils.formatVariable('tween_$tag');
			PyUtils.cancelTween(tag);

			var variables = MusicBeatState.getVariables();
			variables.set(tag, FlxTween.tween(strumNote, data, duration, {ease: PyUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween)
				{
					variables.remove(tag);
					if(PlayState.instance != null) PlayState.instance.callOnPythons('onTweenCompleted', [originalTag]);
				}
			}));
			return tag;
		}
		else FlxTween.tween(strumNote, data, duration, {ease: PyUtils.getTweenEaseByString(ease)});
		return null;
	}
}

#end