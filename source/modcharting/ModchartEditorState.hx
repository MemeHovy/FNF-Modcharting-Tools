package modcharting;

import haxe.Json;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flixel.graphics.FlxGraphic;
import flixel.addons.display.FlxBackdrop;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxTween.FlxTweenManager;
import flixel.addons.ui.FlxSlider;
import flixel.text.FlxText;
import openfl.geom.Rectangle;
import openfl.display.BitmapData;
import flixel.util.FlxColor;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxMath;
import flixel.FlxSprite;
import flixel.util.FlxSort;
import flixel.system.FlxSound;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxCamera;
import flixel.FlxG;
import Section.SwagSection;
import Song.SwagSong;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;



import modcharting.*;
import modcharting.PlayfieldRenderer.StrumNoteType;
import modcharting.Modifier;
import modcharting.ModchartFile;
using StringTools;

class ModchartEditorEvent extends FlxSprite
{
    public var data:Array<Dynamic>;
    public function new (data:Array<Dynamic>)
    {
        this.data = data;
        super(-300, 0);
        makeGraphic(48, 48);
    }
    public function getBeatTime():Float { return data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME]; }
}

class ModchartEditorState extends ModchartMusicBeatState
{
    //only works on psych right now, but modcharts made with this should work on other engines
    #if PSYCH

    //pain
    //tried using a macro but idk how to use them lol
    public static var modifierList:Array<Class<Modifier>> = [
        DrunkXModifier, DrunkYModifier, DrunkZModifier,
        TipsyXModifier, TipsyYModifier, TipsyZModifier,
        ReverseModifier, IncomingAngleModifier, RotateModifier, 
        BumpyModifier,
        XModifier, YModifier, ZModifier, ConfusionModifier, 
        ScaleModifier, ScaleXModifier, ScaleYModifier, SpeedModifier, 
        StealthModifier, NoteStealthModifier, InvertModifier, FlipModifier, 
        MiniModifier, ShrinkModifier, BeatXModifier, BeatYModifier, BeatZModifier, 
        BounceXModifier, BounceYModifier, BounceZModifier, 
        EaseCurveModifier, EaseCurveXModifier, EaseCurveYModifier, EaseCurveZModifier, EaseCurveAngleModifier,
        InvertSineModifier, BoostModifier, BrakeModifier, JumpModifier
    ];

    public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
    public var notes:FlxTypedGroup<Note>;
    private var strumLine:FlxSprite;
    public var strumLineNotes:FlxTypedGroup<StrumNoteType>;
	public var opponentStrums:FlxTypedGroup<StrumNoteType>;
	public var playerStrums:FlxTypedGroup<StrumNoteType>;
	public var unspawnNotes:Array<Note> = [];
    public var loadedNotes:Array<Note> = [];

    public var vocals:FlxSound;
    var generatedMusic:Bool = false;
    

    private var grid:FlxBackdrop;
    private var line:FlxSprite;
    var gridSize:Int = 64;
    var beatTexts:Array<FlxText> = [];
    public var eventSprites:FlxTypedGroup<ModchartEditorEvent>;
    public static var gridGap:Float = 2;
    public var highlight:FlxSprite;
    public var debugText:FlxText;
    var highlightedEvent:Array<Dynamic> = null;

    var UI_box:FlxUITabMenu;

    var textBlockers:Array<FlxUIInputText> = [];
    var scrollBlockers:Array<FlxUIDropDownMenuCustom> = [];

    var playbackSpeed:Float = 1;


    override public function new()
    {
        super();
    }
    override public function create()
    {
        camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		persistentUpdate = true;
		persistentDraw = true;

		if (PlayState.SONG == null)
			PlayState.SONG = Song.loadFromJson('tutorial');

		Conductor.mapBPMChanges(PlayState.SONG);
		Conductor.changeBPM(PlayState.SONG.bpm);

        FlxG.mouse.visible = true;



        
		strumLine = new FlxSprite(ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if(ClientPrefs.downScroll) strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();

        strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		generateSong(PlayState.SONG.song);

		playfieldRenderer = new PlayfieldRenderer(strumLineNotes, notes, this);
		playfieldRenderer.cameras = [camHUD];
        playfieldRenderer.inEditor = true;
		add(playfieldRenderer);

        //strumLineNotes.cameras = [camHUD];
		//notes.cameras = [camHUD];

        grid = new FlxBackdrop(FlxGraphic.fromBitmapData(createGrid(gridSize, gridSize, Std.int(gridSize*48), gridSize)), 0, 0, true, false);
        add(grid);
        
        for (i in 0...12)
        {
            var beatText = new FlxText(-50, gridSize, 0, i+"", 32);
            add(beatText);
            beatTexts.push(beatText);
        }

        eventSprites = new FlxTypedGroup<ModchartEditorEvent>();
        add(eventSprites);

        highlight = new FlxSprite().makeGraphic(gridSize,gridSize);
        highlight.alpha = 0.5;
        add(highlight);

        updateEventSprites();

        line = new FlxSprite().makeGraphic(10, gridSize);
        add(line);

        generateStaticArrows(0);
        generateStaticArrows(1);
        NoteMovement.getDefaultStrumPosEditor(this);

        gridGap = FlxMath.remapToRange(Conductor.stepCrochet, 0, Conductor.stepCrochet, 0, gridSize);

        debugText = new FlxText(0, gridSize*2, 0, "", 16);
        debugText.alignment = FlxTextAlign.LEFT;
        

        var tabs = [
            {name: "Editor", label: 'Editor'},
			{name: "Modifiers", label: 'Modifiers'},
			{name: "Events", label: 'Events'},
			{name: "Playfields", label: 'Playfields'},
		];
        
        UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(FlxG.width-200, 550);
		UI_box.x = 100;
		UI_box.y = gridSize*2;
		UI_box.scrollFactor.set();
        add(UI_box);

        add(debugText);

        setupEditorUI();
        setupModifierUI();
        setupEventUI();
        setupPlayfieldUI();


        var hideNotes:FlxButton = new FlxButton(0, FlxG.height, 'Show/Hide Notes', function ()
        {
            camHUD.visible = !camHUD.visible;
        });
        hideNotes.scale.y *= 1.5;
        hideNotes.updateHitbox();
        hideNotes.y -= hideNotes.height;
        add(hideNotes);
        
        var hideUI:FlxButton = new FlxButton(FlxG.width, FlxG.height, 'Show/Hide UI', function ()
        {
            UI_box.visible = !UI_box.visible;
            debugText.visible = !debugText.visible;
            //camGame.visible = !camGame.visible;
        });
        hideUI.y -= hideUI.height;
        hideUI.x -= hideUI.width;
        add(hideUI);


        super.create();
    }
    var dirtyUpdateNotes:Bool = false;
    var dirtyUpdateEvents:Bool = false;
    var dirtyUpdateModifiers:Bool = false;
    var totalElapsed:Float = 0;
    override public function update(elapsed:Float)
    {
        totalElapsed += elapsed;
        highlight.alpha = 0.8+Math.sin(totalElapsed*5)*0.15;
        super.update(elapsed);
        if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
        Conductor.songPosition = FlxG.sound.music.time;

        
        var songPosPixelPos = (((Conductor.songPosition/Conductor.stepCrochet)%4)*gridGap);
        grid.x = -curDecStep*gridGap;
        line.x = gridGap*4;

        for (i in 0...beatTexts.length)
        {
            beatTexts[i].x = -songPosPixelPos + (gridGap*4*(i+1)) - 16;
            beatTexts[i].text = ""+ (Math.floor(Conductor.songPosition/Conductor.crochet)+i);
        }
        for (i in 0...eventSprites.members.length)
        {
            var pos = grid.x + (eventSprites.members[i].getBeatTime()*gridGap*4)+(gridGap*4);
            //var dec = eventSprites.members[i].beatTime-Math.floor(eventSprites.members[i].beatTime);
            eventSprites.members[i].x = pos; //+ (dec*4*gridGap);
        }


        var blockInput = false;
        for (i in textBlockers)
            if (i.hasFocus)
                blockInput = true;
        for (i in scrollBlockers)
            if (i.dropPanel.visible)
                blockInput = true;
        

        if (!blockInput)
        {
            if (FlxG.keys.justPressed.SPACE)
            {
                if (FlxG.sound.music.playing)
                {
                    FlxG.sound.music.pause();
                    if(vocals != null) vocals.pause();
                    playfieldRenderer.editorPaused = true;
                }
                else
                {
                    if(vocals != null) {
                        vocals.play();
                        vocals.pause();
                        vocals.time = FlxG.sound.music.time;
                        vocals.play();
                    }
                    FlxG.sound.music.play();
                    playfieldRenderer.editorPaused = false;
                    dirtyUpdateNotes = true;
                    dirtyUpdateEvents = true;
                }
            }
            var shiftThing:Int = 1;
            if (FlxG.keys.pressed.SHIFT)
                shiftThing = 4;
            if (FlxG.mouse.wheel != 0)
            {
                FlxG.sound.music.pause();
                if(vocals != null) vocals.pause();
                FlxG.sound.music.time += (FlxG.mouse.wheel * Conductor.stepCrochet*0.8*shiftThing);
                if(vocals != null) {
                    vocals.pause();
                    vocals.time = FlxG.sound.music.time;
                }
                playfieldRenderer.editorPaused = true;
                dirtyUpdateNotes = true;
                dirtyUpdateEvents = true;
            }
    
            if (FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT)
            {
                FlxG.sound.music.pause();
                if(vocals != null) vocals.pause();
                FlxG.sound.music.time += (Conductor.crochet*4*shiftThing);
                dirtyUpdateNotes = true;
                dirtyUpdateEvents = true;
            }
            if (FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT) 
            {
                FlxG.sound.music.pause();
                if(vocals != null) vocals.pause();
                FlxG.sound.music.time -= (Conductor.crochet*4*shiftThing);
                dirtyUpdateNotes = true;
                dirtyUpdateEvents = true;
            }
            var holdingShift = FlxG.keys.pressed.SHIFT;
            var holdingLB = FlxG.keys.pressed.LBRACKET;
            var holdingRB = FlxG.keys.pressed.RBRACKET;
            var pressedLB = FlxG.keys.justPressed.LBRACKET;
            var pressedRB = FlxG.keys.justPressed.RBRACKET;

            var curSpeed = playbackSpeed;
    
            if (!holdingShift && pressedLB || holdingShift && holdingLB)
                playbackSpeed -= 0.01;
            if (!holdingShift && pressedRB || holdingShift && holdingRB)
                playbackSpeed += 0.01;
            if (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB))
                playbackSpeed = 1;
            //
            if (curSpeed != playbackSpeed)
                dirtyUpdateEvents = true;
        }
            
        if (playbackSpeed <= 0.5)
            playbackSpeed = 0.5;
        if (playbackSpeed >= 3)
            playbackSpeed = 3;

        playfieldRenderer.speed = playbackSpeed; //adjust the speed of tweens
        FlxG.sound.music.pitch = playbackSpeed;
        vocals.pitch = playbackSpeed;
        

        if (unspawnNotes[0] != null)
        {
            var time:Float = 2000;
            if(PlayState.SONG.speed < 1) time /= PlayState.SONG.speed;

            while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
            {
                var dunceNote:Note = unspawnNotes[0];
                notes.insert(0, dunceNote);
                dunceNote.spawned=true;
                var index:Int = unspawnNotes.indexOf(dunceNote);
                unspawnNotes.splice(index, 1);
            }
        }

        var noteKillOffset = 350 / PlayState.SONG.speed;

        notes.forEachAlive(function(daNote:Note) {
            if (Conductor.songPosition >= daNote.strumTime)
            {
                daNote.wasGoodHit = true;
                var strum = strumLineNotes.members[daNote.noteData+(daNote.mustPress ? 4 : 0)];
                strum.playAnim("confirm", true);
                strum.resetAnim = 0.15;
                if(daNote.isSustainNote && !daNote.animation.curAnim.name.endsWith('end')) {
                    strum.resetAnim = 0.3;
                }
                if (!daNote.isSustainNote)
                {
                    //daNote.kill();
                    notes.remove(daNote, true);
                    //daNote.destroy();
                }
            }

            if (Conductor.songPosition > noteKillOffset + daNote.strumTime)
            {
                daNote.active = false;
                daNote.visible = false;

                //daNote.kill();
                notes.remove(daNote, true);
                //daNote.destroy();
            }
        });

        if (FlxG.mouse.y < grid.y+grid.height && FlxG.mouse.y > grid.y) //not using overlap because the grid would go out of world bounds
        {
            if (FlxG.keys.pressed.SHIFT)
                highlight.x = FlxG.mouse.x;
            else
                highlight.x = (Math.floor(FlxG.mouse.x/gridGap)*gridGap)+(grid.x%gridGap);
            if (FlxG.mouse.overlaps(eventSprites))
            {
                eventSprites.forEachAlive(function(event:ModchartEditorEvent)
                {
                    if (FlxG.mouse.overlaps(event))
                    {
                        if (FlxG.mouse.pressed)
                        {
                            highlightedEvent = event.data;
                            onSelectEvent();
                        }   
                        if (FlxG.keys.justPressed.DELETE)
                            deleteEvent();
                    }
                });
            }
            else 
            {
                if (FlxG.mouse.justPressed)
                {
                    var timeFromMouse = ((highlight.x-grid.x)/gridGap/4)-1;
                    //trace(timeFromMouse);
                    var event:Array<Dynamic> = ['ease', [timeFromMouse, 1, 'cubeInOut', ',']];
                    playfieldRenderer.modchart.data.events.push(event);
                    updateEventSprites();
                    dirtyUpdateEvents = true;
                }
            }
        }

        if (dirtyUpdateNotes)
        {
            clearNotesAfter(Conductor.songPosition+2000); //so scrolling back doesnt lag shit
            unspawnNotes = loadedNotes.copy();
            clearNotesBefore(Conductor.songPosition);
            dirtyUpdateNotes = false;
        }
        if (dirtyUpdateModifiers)
        {
            playfieldRenderer.modifiers.clear();
            playfieldRenderer.modchart.loadModifiers();
            dirtyUpdateEvents = true;
            dirtyUpdateModifiers = false;
        }
        if (dirtyUpdateEvents)
        {
            FlxTween.globalManager.completeAll();
            playfieldRenderer.events = [];
            for (mod in playfieldRenderer.modifiers)
                mod.reset();
            playfieldRenderer.modchart.loadEvents();
            dirtyUpdateEvents = false;
            playfieldRenderer.update(0);
        }

        if (playfieldRenderer.modchart.data.playfields != playfieldCountStepper.value)
        {
            playfieldRenderer.modchart.data.playfields = Std.int(playfieldCountStepper.value);
            playfieldRenderer.modchart.loadPlayfields();
        }


        if (FlxG.keys.justPressed.ESCAPE)
        {
            FlxG.mouse.visible = false;
            FlxG.sound.music.stop();
            if(vocals != null) vocals.stop();
            StageData.loadDirectory(PlayState.SONG);
            LoadingState.loadAndSwitchState(new PlayState());
        }






        debugText.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)) + " / " + Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2)) +
		"\nBeat: " + Std.string(curDecBeat).substring(0,4) +
		"\nStep: " + curStep + "\n";
    }

    function updateEventSprites()
    {
        /*var i = eventSprites.length - 1;
        while (i >= 0) {
            var daEvent:ModchartEditorEvent = eventSprites.members[i];
            if(curBeat < daEvent.beatTime-4 && curBeat > daEvent.beatTime+16)
            {
                daEvent.active = false;
                daEvent.visible = false;
                eventSprites.remove(daEvent, true);
                trace(daEvent.beatTime);
                trace("removed event sprite "+ daEvent.beatTime);
            }
            --i;
        }*/
        eventSprites.clear();

        for (i in 0...playfieldRenderer.modchart.data.events.length)
        {
            var beat:Float = playfieldRenderer.modchart.data.events[i][1][0];
            if (curBeat > beat-5  && curBeat < beat+5)
            {
                var daEvent:ModchartEditorEvent = new ModchartEditorEvent(playfieldRenderer.modchart.data.events[i]);
                eventSprites.add(daEvent);
                //trace("added event sprite "+beat);
            }
        }
    }

    function deleteEvent()
    {
        if (highlightedEvent == null)
            return;
        for (i in 0...playfieldRenderer.modchart.data.events.length)
        {
            if (highlightedEvent == playfieldRenderer.modchart.data.events[i])
            {
                playfieldRenderer.modchart.data.events.remove(playfieldRenderer.modchart.data.events[i]);
                dirtyUpdateEvents = true;
                break;
            }
        }
        updateEventSprites();
    }

    override public function beatHit()
    {
        updateEventSprites();
        //trace("beat hit");
        super.beatHit();
    }

    override public function draw()
    {

        super.draw();
    }

    public function clearNotesBefore(time:Float)
    {
        var i:Int = unspawnNotes.length - 1;
        while (i >= 0) {
            var daNote:Note = unspawnNotes[i];
            if(daNote.strumTime+350 < time)
            {
                daNote.active = false;
                daNote.visible = false;
                //daNote.ignoreNote = true;

                //daNote.kill();
                unspawnNotes.remove(daNote);
                //daNote.destroy();
            }
            --i;
        }

        i = notes.length - 1;
        while (i >= 0) {
            var daNote:Note = notes.members[i];
            if(daNote.strumTime+350 < time)
            {
                daNote.active = false;
                daNote.visible = false;
                //daNote.ignoreNote = true;

                //daNote.kill();
                notes.remove(daNote, true);
                //daNote.destroy();
            }
            --i;
        }
    }
    public function clearNotesAfter(time:Float)
    {
        var i = notes.length - 1;
        while (i >= 0) {
            var daNote:Note = notes.members[i];
            if(daNote.strumTime > time)
            {
                daNote.active = false;
                daNote.visible = false;
                //daNote.ignoreNote = true;

                //daNote.kill();
                notes.remove(daNote, true);
                //daNote.destroy();
            }
            --i;
        }
    }


    private function generateSong(dataPath:String):Void
    {

        var songData = PlayState.SONG;
        Conductor.changeBPM(songData.bpm);

        if (PlayState.SONG.needsVoices)
            vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
        else
            vocals = new FlxSound();

        //vocals.pitch = playbackRate;
        FlxG.sound.list.add(vocals);
        FlxG.sound.list.add(new FlxSound().loadEmbedded(Paths.inst(PlayState.SONG.song)));

        FlxG.sound.music.onComplete = function()
        {
            FlxG.sound.music.pause();
            Conductor.songPosition = 0;
            if(vocals != null) {
                vocals.pause();
                vocals.time = 0;
            }
        };

        notes = new FlxTypedGroup<Note>();
        add(notes);

        var noteData:Array<SwagSection>;

        // NEW SHIT
        noteData = songData.notes;

        var playerCounter:Int = 0;

        var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

        var songName:String = Paths.formatToSongPath(PlayState.SONG.song);

        for (section in noteData)
        {
            for (songNotes in section.sectionNotes)
            {
                var daStrumTime:Float = songNotes[0];
                var daNoteData:Int = Std.int(songNotes[1] % 4);

                var gottaHitNote:Bool = section.mustHitSection;

                if (songNotes[1] > 3)
                {
                    gottaHitNote = !section.mustHitSection;
                }

                var oldNote:Note;
                if (unspawnNotes.length > 0)
                    oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
                else
                    oldNote = null;

                var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
                swagNote.mustPress = gottaHitNote;
                swagNote.sustainLength = songNotes[2];
                swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
                swagNote.noteType = songNotes[3];
                if(!Std.isOfType(songNotes[3], String)) swagNote.noteType = editors.ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts

                swagNote.scrollFactor.set();

                var susLength:Float = swagNote.sustainLength;

                susLength = susLength / Conductor.stepCrochet;
                unspawnNotes.push(swagNote);

                var floorSus:Int = Math.floor(susLength);
                if(floorSus > 0) {
                    for (susNote in 0...floorSus+1)
                    {
                        oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

                        var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(PlayState.SONG.speed, 2)), daNoteData, oldNote, true);
                        sustainNote.mustPress = gottaHitNote;
                        sustainNote.gfNote = (section.gfSection && (songNotes[1]<4));
                        sustainNote.noteType = swagNote.noteType;
                        sustainNote.scrollFactor.set();
                        swagNote.tail.push(sustainNote);
                        sustainNote.parent = swagNote;
                        unspawnNotes.push(sustainNote);
                    }
                }
            }
            daBeats += 1;
        }

        unspawnNotes.sort(sortByTime);
        loadedNotes = unspawnNotes.copy();
        generatedMusic = true;
    }
    function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
    {
        return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
    }


    private function generateStaticArrows(player:Int):Void
    {
        for (i in 0...4)
        {
            // FlxG.log.add(i);
            var targetAlpha:Float = 1;
            if (player < 1)
            {
                if(!ClientPrefs.opponentStrums) targetAlpha = 0;
                else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
            }

            var babyArrow:StrumNote = new StrumNote(ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X, strumLine.y, i, player);
            babyArrow.downScroll = ClientPrefs.downScroll;
            babyArrow.alpha = targetAlpha;

            if (player == 1)
            {
                playerStrums.add(babyArrow);
            }
            else
            {
                if(ClientPrefs.middleScroll)
                {
                    babyArrow.x += 310;
                    if(i > 1) { //Up and Right
                        babyArrow.x += FlxG.width / 2 + 25;
                    }
                }
                opponentStrums.add(babyArrow);
            }

            strumLineNotes.add(babyArrow);
            babyArrow.postAddedToGroup();
        }
    }
    


    public static function createGrid(CellWidth:Int, CellHeight:Int, Width:Int, Height:Int):BitmapData
    {
        // How many cells can we fit into the width/height? (round it UP if not even, then trim back)
        var Color1 = FlxColor.RED; //quant colors!!!
        var Color2 = FlxColor.BLUE;
        var Color3 = FlxColor.LIME;
        var rowColor:Int = Color1;
        var lastColor:Int = Color1;
        var grid:BitmapData = new BitmapData(Width, Height, true);

        // If there aren't an even number of cells in a row then we need to swap the lastColor value
        var y:Int = 0;
        var timesFilled:Int = 0;
        while (y <= Height)
        {

            var x:Int = 0;
            while (x <= Width)
            {
                if (timesFilled % 4 == 0)
                    lastColor = Color1;
                else if (timesFilled % 4 == 2)
                    lastColor = Color2;
                else 
                    lastColor = Color3;

                grid.fillRect(new Rectangle(x, y, CellWidth, CellHeight), lastColor);
                timesFilled++;

                x += CellWidth;
            }

            y += CellHeight;
        }

        return grid;
    }
    var currentModifier:Array<Dynamic> = null;
    var modNameInputText:FlxUIInputText;
    var modClassInputText:FlxUIInputText;
    var modTypeInputText:FlxUIInputText;
    var playfieldStepper:FlxUINumericStepper;
    var targetLaneStepper:FlxUINumericStepper;
    var modifierDropDown:FlxUIDropDownMenuCustom;
    var mods:Array<String> = [];
    function updateModList()
    {
        mods = [];
        for (i in 0...playfieldRenderer.modchart.data.modifiers.length)
            mods.push(playfieldRenderer.modchart.data.modifiers[i][ModchartFile.MOD_NAME]);
        modifierDropDown.setData(FlxUIDropDownMenuCustom.makeStrIdLabelArray(mods, true));
        eventModifierDropDown.setData(FlxUIDropDownMenuCustom.makeStrIdLabelArray(mods, true));
    }
    function setupModifierUI()
    {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Modifiers";

        
        for (i in 0...playfieldRenderer.modchart.data.modifiers.length)
            mods.push(playfieldRenderer.modchart.data.modifiers[i][ModchartFile.MOD_NAME]);
        

        modifierDropDown = new FlxUIDropDownMenuCustom(25, 50, FlxUIDropDownMenuCustom.makeStrIdLabelArray(mods, true), function(mod:String)
        {
            var modName = mods[Std.parseInt(mod)];
            for (i in 0...playfieldRenderer.modchart.data.modifiers.length)
                if (playfieldRenderer.modchart.data.modifiers[i][ModchartFile.MOD_NAME] == modName)
                    currentModifier = playfieldRenderer.modchart.data.modifiers[i];

            if (currentModifier != null)
            {
                //trace(currentModifier);
                modNameInputText.text = currentModifier[ModchartFile.MOD_NAME];
                modClassInputText.text = currentModifier[ModchartFile.MOD_CLASS];
                modTypeInputText.text = currentModifier[ModchartFile.MOD_TYPE];
                playfieldStepper.value = currentModifier[ModchartFile.MOD_PF];
            }   
        });




        var refreshModifiers:FlxButton = new FlxButton(25+modifierDropDown.width+10, modifierDropDown.y, 'Refresh Modifiers', function ()
        {
            updateModList();
        });
        refreshModifiers.scale.y *= 1.5;
        refreshModifiers.updateHitbox();

        var saveModifier:FlxButton = new FlxButton(refreshModifiers.x, refreshModifiers.y+refreshModifiers.height+20, 'Save Modifier', function ()
        {
            var alreadyExists = false;
            for (i in 0...playfieldRenderer.modchart.data.modifiers.length)
                if (playfieldRenderer.modchart.data.modifiers[i][ModchartFile.MOD_NAME] == modNameInputText.text)
                {
                    playfieldRenderer.modchart.data.modifiers[i] = [modNameInputText.text, modClassInputText.text, 
                        modTypeInputText.text, playfieldStepper.value];
                    alreadyExists = true;
                }

            if (!alreadyExists)
            {
                playfieldRenderer.modchart.data.modifiers.push([modNameInputText.text, modClassInputText.text, 
                    modTypeInputText.text, playfieldStepper.value]);
            }
            dirtyUpdateModifiers = true;
            updateModList();
        });

        var removeModifier:FlxButton = new FlxButton(saveModifier.x, saveModifier.y+saveModifier.height+20, 'Remove Modifier', function ()
        {
            for (i in 0...playfieldRenderer.modchart.data.modifiers.length)
                if (playfieldRenderer.modchart.data.modifiers[i][ModchartFile.MOD_NAME] == modNameInputText.text)
                {
                    playfieldRenderer.modchart.data.modifiers.remove(playfieldRenderer.modchart.data.modifiers[i]);
                }
            dirtyUpdateModifiers = true;
            updateModList();
        });
        removeModifier.scale.y *= 1.5;
        removeModifier.updateHitbox();

        modNameInputText = new FlxUIInputText(modifierDropDown.x + 300, modifierDropDown.y, 160, '', 8);
        modClassInputText = new FlxUIInputText(modifierDropDown.x + 500, modifierDropDown.y, 160, '', 8);
        modTypeInputText = new FlxUIInputText(modifierDropDown.x + 700, modifierDropDown.y, 160, '', 8);
        playfieldStepper = new FlxUINumericStepper(modifierDropDown.x + 900, modifierDropDown.y, 1, -1, -1, 100, 0);

        textBlockers.push(modNameInputText);
        textBlockers.push(modClassInputText);
        textBlockers.push(modTypeInputText);
        scrollBlockers.push(modifierDropDown);


        var modClassList:Array<String> = [];
        for (i in 0...modifierList.length)
        {
            modClassList.push(Std.string(modifierList[i]).replace("modcharting.", ""));
        }
            
        var modClassDropDown = new FlxUIDropDownMenuCustom(modClassInputText.x, modClassInputText.y+30, FlxUIDropDownMenuCustom.makeStrIdLabelArray(modClassList, true), function(mod:String)
        {
            modClassInputText.text = modClassList[Std.parseInt(mod)];
        });
        centerXToObject(modClassInputText, modClassDropDown);
        var modTypeList = ["All", "Player", "Opponent", "Lane"];
        var modTypeDropDown = new FlxUIDropDownMenuCustom(modTypeInputText.x, modClassInputText.y+30, FlxUIDropDownMenuCustom.makeStrIdLabelArray(modTypeList, true), function(mod:String)
        {
            modTypeInputText.text = modTypeList[Std.parseInt(mod)];
        });
        centerXToObject(modTypeInputText, modTypeDropDown);

        scrollBlockers.push(modTypeDropDown);
        scrollBlockers.push(modClassDropDown);
        

        tab_group.add(modNameInputText);
        tab_group.add(modClassInputText);
        tab_group.add(modTypeInputText);
        tab_group.add(playfieldStepper);

        tab_group.add(refreshModifiers);
        tab_group.add(saveModifier);
        tab_group.add(removeModifier);

        tab_group.add(makeLabel(modNameInputText, 0, -15, "Modifier Name"));
        tab_group.add(makeLabel(modClassInputText, 0, -15, "Modifier Class"));
        tab_group.add(makeLabel(modTypeInputText, 0, -15, "Modifier Type"));
        tab_group.add(makeLabel(playfieldStepper, 0, -15, "Playfield (-1 = all)"));
        tab_group.add(makeLabel(playfieldStepper, 0, 15, "Playfield number starts at 0!"));

        tab_group.add(modifierDropDown);
        tab_group.add(modClassDropDown);
        tab_group.add(modTypeDropDown);
        UI_box.addGroup(tab_group);
    }
    var eventTimeStepper:FlxUINumericStepper;
    var eventModInputText:FlxUIInputText;
    var eventValueInputText:FlxUIInputText;
    var eventDataInputText:FlxUIInputText;
    var eventModifierDropDown:FlxUIDropDownMenuCustom;
    var eventTypeDropDown:FlxUIDropDownMenuCustom;
    var eventEaseInputText:FlxUIInputText;
    var eventTimeInputText:FlxUIInputText;

    function findCorrectModData(data:Array<Dynamic>) //the data is stored at different indexes based on the type (maybe should have kept them the same)
    {
        switch(data[ModchartFile.EVENT_TYPE])
        {
            case "ease": 
                return data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA]; 
            case "set": 
                return data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_SETDATA];
        }
        return null;
    }
    function setCorrectModData(data:Array<Dynamic>, dataStr:String)
    {
        switch(data[ModchartFile.EVENT_TYPE])
        {
            case "ease": 
                data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA] = dataStr;
            case "set": 
                data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_SETDATA] = dataStr;
        }
        return data;
    }
    function convertModData(data:Array<Dynamic>, newType:String)
    {
        switch(data[ModchartFile.EVENT_TYPE]) //convert stuff over i guess
        {
            case "ease": 
                if (newType == 'set')
                {
                    var temp:Array<Dynamic> = [newType, [
                        data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME],
                        data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA],
                    ]];
                    data = temp;
                }
            case "set": 
                if (newType == 'ease')
                {
                    trace('converting set to ease');
                    var temp:Array<Dynamic> = [newType, [
                        data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME],
                        1,
                        "linear",
                        data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_SETDATA],
                    ]];
                    trace(temp);
                    data = temp;
                }
        } 
        //trace(data);
        return data;
    }

    function updateEventModData(shitToUpdate:String, isMod:Bool)
    {
        var data = getCurrentEventInData();
        if (data != null)
        {
            var dataStr:String = findCorrectModData(data);
            var dataSplit = dataStr.split(',');
            //the way the data works is it goes "value,mod,value,mod,....." and goes on forever, so it has to deconstruct and reconstruct to edit it and shit

            dataSplit[(getEventModIndex()*2)+(isMod ? 1 : 0)] = shitToUpdate;
            dataStr = stringifyEventModData(dataSplit);
            data = setCorrectModData(data, dataStr);
        }
    }
    function getEventModData(isMod:Bool) : String
    {
        var data = getCurrentEventInData();
        if (data != null)
        {
            var dataStr:String = findCorrectModData(data);
            var dataSplit = dataStr.split(',');
            return dataSplit[(getEventModIndex()*2)+(isMod ? 1 : 0)];
        }
        return "";
    }
    function stringifyEventModData(dataSplit:Array<String>) : String
    {
        var dataStr = "";
        for (i in 0...dataSplit.length)
        {
            dataStr += dataSplit[i];
            if (i < dataSplit.length-1)
                dataStr += ',';
        }
        return dataStr;
    }
    function addNewModData()
    {
        var data = getCurrentEventInData();
        if (data != null)
        {
            var dataStr:String = findCorrectModData(data);
            dataStr += ",,"; //just how it works lol
            data = setCorrectModData(data, dataStr);
        }
        return data;
    }
    function removeModData()
    {
        var data = getCurrentEventInData();
        if (data != null)
        {
            if (selectedEventDataStepper.max > 0)
            {
                var dataStr:String = findCorrectModData(data);
                var dataSplit = dataStr.split(',');
                dataSplit.resize(dataSplit.length-2); //remove last 2 things
                dataStr = stringifyEventModData(dataSplit);
                data = setCorrectModData(data, dataStr);
            }
        }
        return data;
    }
    var selectedEventDataStepper:FlxUINumericStepper;
    function setupEventUI()
    {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Events";

        eventTimeStepper = new FlxUINumericStepper(850, 50, 0.25, 0, 0, 9999, 3);





        eventModInputText = new FlxUIInputText(25, 50, 160, '', 8);
        eventModInputText.callback = function(str:String, str2:String)
        {
            updateEventModData(eventModInputText.text, true);
            var data = getCurrentEventInData();
            if (data != null)
            {
                highlightedEvent = data; 
                eventDataInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA];
                dirtyUpdateEvents = true;
            }
        };
        eventValueInputText = new FlxUIInputText(25 + 200, 50, 160, '', 8);
        eventValueInputText.callback = function(str:String, str2:String)
        {
            updateEventModData(eventValueInputText.text, false);
            var data = getCurrentEventInData();
            if (data != null)
            {
                highlightedEvent = data; 
                eventDataInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA];
                dirtyUpdateEvents = true;
            }
        };

        selectedEventDataStepper = new FlxUINumericStepper(25 + 400, 50, 1, 0, 0, 0, 0);
        selectedEventDataStepper.name = "selectedEventMod";        

        eventTypeDropDown = new FlxUIDropDownMenuCustom(25 + 500, 50, FlxUIDropDownMenuCustom.makeStrIdLabelArray(eventTypes, true), function(mod:String)
        {
            var et = eventTypes[Std.parseInt(mod)];
            trace(et);
            var data = getCurrentEventInData();
            if (data != null)
            {
                //if (data[ModchartFile.EVENT_TYPE] != et)
                data = convertModData(data, et);
                highlightedEvent = data;
                trace(highlightedEvent);
            }
            eventEaseInputText.alpha = 1;
            eventTimeInputText.alpha = 1;
            if (et != 'ease')
            {
                eventEaseInputText.alpha = 0.5;
                eventTimeInputText.alpha = 0.5;
            }
            dirtyUpdateEvents = true;
        });
        eventEaseInputText = new FlxUIInputText(25 + 650, 50+100, 160, '', 8);
        eventTimeInputText = new FlxUIInputText(25 + 650, 50, 160, '', 8);
        eventEaseInputText.callback = function(str:String, str2:String)
        {
            var data = getCurrentEventInData();
            if (data != null)
            {
                if (data[ModchartFile.EVENT_TYPE] == 'ease')
                    data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASE] = eventEaseInputText.text;
            }
        }
        eventTimeInputText.callback = function(str:String, str2:String)
        {
            var data = getCurrentEventInData();
            if (data != null)
            {
                if (data[ModchartFile.EVENT_TYPE] == 'ease')
                    data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASETIME] = eventTimeInputText.text;
            }
        }



        eventModifierDropDown = new FlxUIDropDownMenuCustom(25, 50+20, FlxUIDropDownMenuCustom.makeStrIdLabelArray(mods, true), function(mod:String)
        {
            var modName = mods[Std.parseInt(mod)];
            eventModInputText.text = modName;
            eventModInputText.callback("", ""); //make sure it updates
        });
        centerXToObject(eventModInputText, eventModifierDropDown);

        eventDataInputText = new FlxUIInputText(25, 300, 300, '', 8);
        //eventDataInputText.resize(300, 300);
        eventDataInputText.callback = function(str:String, str2:String)
        {
            var data = getCurrentEventInData();
            if (data != null)
            {
                data[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA] = eventDataInputText.text;
                highlightedEvent = data; 
                dirtyUpdateEvents = true;
            }
        };

        var add:FlxButton = new FlxButton(0, selectedEventDataStepper.y+30, 'Add', function ()
        {
            var data = addNewModData();
            if (data != null)
            {
                highlightedEvent = data; 
                updateSelectedEventDataStepper();
                eventDataInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA];
                eventModInputText.text = getEventModData(true);
                eventValueInputText.text = getEventModData(false);
                dirtyUpdateEvents = true;
            }
        });
        var remove:FlxButton = new FlxButton(0, selectedEventDataStepper.y+50, 'Remove', function ()
        {
            var data = removeModData();
            if (data != null)
            {
                highlightedEvent = data; 
                updateSelectedEventDataStepper();
                eventDataInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA];
                eventModInputText.text = getEventModData(true);
                eventValueInputText.text = getEventModData(false);
                dirtyUpdateEvents = true;
            }
        });
        centerXToObject(selectedEventDataStepper, add);
        centerXToObject(selectedEventDataStepper, remove);
        tab_group.add(add);
        tab_group.add(remove);

       
        textBlockers.push(eventModInputText);
        textBlockers.push(eventDataInputText);
        textBlockers.push(eventValueInputText);
        textBlockers.push(eventEaseInputText);
        textBlockers.push(eventTimeInputText);
        scrollBlockers.push(eventModifierDropDown);
        scrollBlockers.push(eventTypeDropDown);

        tab_group.add(eventDataInputText);

        tab_group.add(eventValueInputText);
        tab_group.add(eventModInputText);

        tab_group.add(eventEaseInputText);
        tab_group.add(eventTimeInputText);
        tab_group.add(makeLabel(eventEaseInputText, 0, -15, "Event Ease"));
        tab_group.add(makeLabel(eventTimeInputText, 0, -15, "Event Ease Time (in Beats)"));
        tab_group.add(makeLabel(eventTypeDropDown, 0, -15, "Event Type"));

        tab_group.add(eventTimeStepper);
        tab_group.add(selectedEventDataStepper);
        tab_group.add(makeLabel(selectedEventDataStepper, 0, -15, "Selected Data Index"));
        tab_group.add(makeLabel(eventDataInputText, 0, -15, "Raw Event Data"));
        tab_group.add(makeLabel(eventValueInputText, 0, -15, "Event Value"));
        tab_group.add(makeLabel(eventModInputText, 0, -15, "Event Mod"));
        tab_group.add(eventModifierDropDown);
        tab_group.add(eventTypeDropDown);
        UI_box.addGroup(tab_group);
    }
    var playfieldCountStepper:FlxUINumericStepper;
    function setupPlayfieldUI()
    {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Playfields";

        playfieldCountStepper = new FlxUINumericStepper(25, 50, 1, 1, 1, 100, 0);
        playfieldCountStepper.value = playfieldRenderer.modchart.data.playfields;
        

        tab_group.add(playfieldCountStepper);
        tab_group.add(makeLabel(playfieldCountStepper, 0, -15, "Playfield Count"));
        tab_group.add(makeLabel(playfieldCountStepper, 55, 25, "Don't add too many or the game will lag!!!"));
        UI_box.addGroup(tab_group);
    }
    var sliderRate:FlxUISlider;
    function setupEditorUI()
    {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Editor";

        sliderRate = new FlxUISlider(this, 'playbackSpeed', 20, 120, 0.5, 3, 250, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = 'Playback Rate';
        sliderRate.callback = function(val:Float)
        {
            dirtyUpdateEvents = true;
        };

        var songSlider = new FlxUISlider(FlxG.sound.music, 'time', 20, 200, 0, FlxG.sound.music.length, 250, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		songSlider.valueLabel.visible = false;
		songSlider.maxLabel.visible = false;
		songSlider.minLabel.visible = false;
        songSlider.nameLabel.text = 'Song Time';
		songSlider.callback = function(fuck:Float)
		{
			vocals.time = FlxG.sound.music.time;
			Conductor.songPosition = FlxG.sound.music.time;
            dirtyUpdateEvents = true;
            dirtyUpdateNotes = true;
		};


        var resetSpeed:FlxButton = new FlxButton(sliderRate.x+300, sliderRate.y, 'Reset', function ()
        {
            playbackSpeed = 1.0;
        });

        var saveJson:FlxButton = new FlxButton(20, 300, 'Save Modchart', function ()
        {
            saveModchartJson(this);
        });
        tab_group.add(saveJson);

		tab_group.add(sliderRate);
        tab_group.add(resetSpeed);
        tab_group.add(songSlider);
        UI_box.addGroup(tab_group);
    }

    function centerXToObject(obj1:FlxSprite, obj2:FlxSprite) //snap second obj to first
    {
        obj2.x = obj1.x + (obj1.width/2) - (obj2.width/2);
    }
    function makeLabel(obj:FlxSprite, offsetX:Float, offsetY:Float, textStr:String)
    {
        var text = new FlxText(0, obj.y+offsetY, 0, textStr);
        centerXToObject(obj, text);
        text.x += offsetX;
        return text;
    }
    function getCurrentEventInData() //find stored data to match with highlighted event
    {
        if (highlightedEvent == null)
            return null;
        for (i in 0...playfieldRenderer.modchart.data.events.length)
        {
            if (playfieldRenderer.modchart.data.events[i] == highlightedEvent)
            {
                return playfieldRenderer.modchart.data.events[i];
            }
        }

        return null;
    }
    function getMaxEventModDataLength()
    {
        var data = getCurrentEventInData();
        if (data != null)
        {
            var dataStr:String = findCorrectModData(data);
            var dataSplit = dataStr.split(',');
            return Math.floor((dataSplit.length/2)-1);
        }
        return 0;
    }
    function updateSelectedEventDataStepper()
    {
        selectedEventDataStepper.max = getMaxEventModDataLength();
        if (selectedEventDataStepper.value > selectedEventDataStepper.max)
            selectedEventDataStepper.value = 0;
    }
    function getEventModIndex() { return Math.floor(selectedEventDataStepper.value); }
    var eventTypes:Array<String> = ["ease", "set"];
    function onSelectEvent()
    {
        //update texts and stuff
        updateSelectedEventDataStepper();
        eventTimeStepper.value = Std.parseFloat(highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME]);
        eventDataInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA];

        eventEaseInputText.alpha = 0.5;
        eventTimeInputText.alpha = 0.5;
        if (highlightedEvent[ModchartFile.EVENT_TYPE] == 'ease')
        {
            eventEaseInputText.alpha = 1;
            eventTimeInputText.alpha = 1;
            eventEaseInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASE];
            eventTimeInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASETIME];
        }
        eventTypeDropDown.selectedLabel = highlightedEvent[ModchartFile.EVENT_TYPE];
        eventModInputText.text = getEventModData(true);
        eventValueInputText.text = getEventModData(false);
        dirtyUpdateEvents = true;
    }

    override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
    {
        if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
        {
            var nums:FlxUINumericStepper = cast sender;
            var wname = nums.name;
            switch(wname)
            {
                case "selectedEventMod": //stupid steppers which dont have normal callbacks
                    if (highlightedEvent != null)
                    {
                        eventDataInputText.text = highlightedEvent[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASEDATA];
                        eventModInputText.text = getEventModData(true);
                        eventValueInputText.text = getEventModData(false);
                    }

            }
        }
    }


    var _file:FileReference;
    public function saveModchartJson(?instance:ModchartMusicBeatState = null) : Void
    {
        if (instance == null)
            instance = PlayState.instance;

		var data:String = Json.stringify(instance.playfieldRenderer.modchart.data, "\t");
        //data = data.replace("\n", "");
        //data = data.replace(" ", "");
        #if sys
        //sys.io.File.saveContent("modchart.json", data.trim()); 
		if ((data != null) && (data.length > 0))
        {
            _file = new FileReference();
            _file.addEventListener(Event.COMPLETE, onSaveComplete);
            _file.addEventListener(Event.CANCEL, onSaveCancel);
            _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
            _file.save(data.trim(), "modchart.json");
        }
        #end


        
    }
    function onSaveComplete(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
    }

    /**
     * Called when the save file dialog is cancelled.
     */
    function onSaveCancel(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
    }

    /**
     * Called if there is an error while saving the gameplay recording.
     */
    function onSaveError(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
    }


    #end
}