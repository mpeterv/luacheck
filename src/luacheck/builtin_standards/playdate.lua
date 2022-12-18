local standards = require "luacheck.standards"

local empty = {}
local read_write = {read_only = false}

-- import statement used by the playdate SDK
local import = {
   fields = {}
}

-- Object oriented programming support
local class = standards.def_fields("extends")

local Object = {
   fields = {}
}

-- Table additions
local table = standards.def_fields("indexOfElement", "getsize", "create", "shallowcopy", "deepcopy")

-- Debugging
local printTable = {
   fields = {}
}

local where = {
   fields = {}
}

-- Profiling
local sample = {
   fields = {}
}

-- JSON
local json = standards.def_fields("decode", "decodeFile", "encode", "encodePretty", "encodeToFile")

-- Text Alignement
local kTextAlignment = standards.def_fields("left", "center", "right")

-- Playdate SDK
local playdate = {
   fields = {
      -- System and Game Metadata
      apiVersion = empty,
      metadata = standards.def_fields("name", "description", "bundleID", "version", "buildNumber", "imagePath",
         "launchSoundPath", "contentWarning", "contentWarning2"),

      -- Game flow
      update = read_write,
      wait = empty,
      stop = empty,
      start = empty,

      -- Game lifecycle
      gameWillTerminate = read_write,
      deviceWillSleep = read_write,
      deviceWillLock = read_write,
      deviceDidUnlock = read_write,
      gameWillPause = read_write,
      gameWillResume = read_write,

      -- Interacting with the System Menu
      getSystemMenu = empty,
      setMenuImage = empty,

      -- Localization
      getSystemLanguage = empty,

      -- Accessibility
      getReduceFlashing = empty,
      getFlipped = empty,

      -- Accelerometer
      startAccelerometer = empty,
      stopAccelerometer = empty,
      readAccelerometer = empty,
      accelerometerIsRunning = empty,

      -- Buttons
      buttonIsPressed = empty,
      kButtonA = empty,
      kButtonB = empty,
      kButtonUp = empty,
      kButtonDown = empty,
      kButtonLeft = empty,
      kButtonRight = empty,
      buttonJustPressed = empty,
      buttonJustReleased = empty,
      getButtonState = empty,
      AButtonDown = read_write,
      AButtonHeld = read_write,
      AButtonUp = read_write,
      BButtonDown = read_write,
      BButtonHeld = read_write,
      BButtonUp = read_write,
      downButtonDown = read_write,
      downButtonUp = read_write,
      leftButtonDown = read_write,
      leftButtonUp = read_write,
      rightButtonDown = read_write,
      rightButtonUp = read_write,
      upButtonDown = read_write,
      upButtonUp = read_write,

      -- Crank
      isCrankDocked = empty,
      getCrankPosition = empty,
      getCrankChange = empty,
      getCrankTicks = empty,
      cranked = read_write,
      crankDocked = read_write,
      crankUndocked = read_write,
      setCrankSoundsDisabled = empty,

      -- Input Handlers
      inputHandlers = standards.def_fields("push", "pop"),

      -- Device Auto Lock
      setAutoLockDisabled = empty,

      -- Date & Time
      getCurrentTimeMilliseconds = empty,
      resetElapsedTime = empty,
      getElapsedTime = empty,
      getSecondsSinceEpoch = empty,
      getTime = empty,
      getGMTTime = empty,
      epochFromTime = empty,
      epochFromGMTTime = empty,
      timeFromEpoch = empty,
      GMTTimeFromEpoch = empty,

      -- Debugging
      argv = empty,
      setNewlinePrinted = empty,
      drawFPS = empty,

      -- Profiling
      getStats = empty,
      setStatsInterval = empty,

      -- Display
      display = standards.def_fields("setRefreshRate", "getRefreshRate", "flush", "getHeight", "getWidth",
         "getSize", "getRect", "setScale", "getScale", "setInverted", "getInverted", "setMosaic",
         "getMosaic", "setOffset", "getOffset", "setFlipped", "loadImage"),

      -- Easing Functions
      easingFunctions = standards.def_fields("linear", "inQuad", "outQuad", "inOutQuad", "outInQuad", "inCubic",
         "outCubic", "inOutCubic", "outInCubic", "inQuart", "outQuart", "inOutQuart", "outInQuart", "inQuint",
         "outQuint", "inOutQuint", "outInQuint", "inSine", "outSine", "inOutSine", "outInSine", "inExpo",
         "outExpo", "inOutExpo", "outInExpo", "inCirc", "outCirc", "inOutCirc", "outInCirc", "inElastic",
         "outElastic", "inOutElastic", "outInElastic", "inBack", "outBack", "inOutBack", "outInBack",
         "outBounce", "inBounce", "inOutBounce", "outInBounce"),

      -- Files
      datastore = standards.def_fields("write", "read", "delete", "writeImage", "readImage"),
      file = standards.def_fields("open", "kFileRead", "kFileWrite", "kFileAppend", "listFiles", "exists",
         "isdir", "mkdir", "delete", "getSize", "getType", "modtime", "rename", "load", "run"),

      -- Geometry
      geometry = {
         fields = {
            affineTransform = standards.def_fields("new"),
            arc = standards.def_fields("new"),
            lineSegment = standards.def_fields("new", "fast_intersection"),
            point = standards.def_fields("new"),
            polygon = standards.def_fields("new"),
            rect = standards.def_fields("new", "fast_intersection", "fast_union"),
            kUnflipped = empty,
            kFlippedX = empty,
            kFlippedY = empty,
            kFlippedXY = empty,
            size = standards.def_fields("new"),
            squaredDistanceToPoint = empty,
            distanceToPoint = empty,
            vector2D = standards.def_fields("new"),
         }
      },

      -- Graphics
      graphics = {
         fields = {
            pushContext = empty,
            popContext = empty,
            clear = empty,
            image = standards.def_fields("new", "kDitherTypeNone", "kDitherTypeDiagonalLine", "kDitherTypeVerticalLine",
            "kDitherTypeHorizontalLine", "kDitherTypeScreen", "kDitherTypeBayer2x2", "kDitherTypeBayer4x4",
            "kDitherTypeBayer8x8", "kDitherTypeFloydSteinberg", "kDitherTypeBurkes", "kDitherTypeAtkinson"),
            imageSizeAtPath = empty,
            kImageUnflipped = empty,
            kImageFlippedX = empty,
            kImageFlippedY = empty,
            kImageFlippedXY = empty,
            checkAlphaCollision = empty,
            setColor = empty,
            kColorBlack = empty,
            kColorWhite = empty,
            kColorClear = empty,
            kColorXOR = empty,
            getColor = empty,
            setBackgroundColor = empty,
            getBackgroundColor = empty,
            setPattern = empty,
            setDitherPattern = empty,
            drawLine = empty,
            setLineCapStyle = empty,
            kLineCapStyleButt = empty,
            kLineCapStyleRound = empty,
            kLineCapStyleSquare = empty,
            drawPixel = empty,
            drawRect = empty,
            fillRect = empty,
            drawRoundRect = empty,
            fillRoundRect = empty,
            drawArc = empty,
            drawCircleAtPoint = empty,
            drawCircleInRect = empty,
            fillCircleAtPoint = empty,
            fillCircleInRect = empty,
            drawEllipseInRect = empty,
            fillEllipseInRect = empty,
            drawPolygon = empty,
            fillPolygon = empty,
            setPolygonFillRule = empty,
            kPolygonFillNonZero = empty,
            kPolygonFillEvenOdd = empty,
            drawTriangle = empty,
            fillTriangle = empty,
            nineSlice = standards.def_fields("new"),
            perlin = empty,
            perlinArray = empty,
            generateQRCode = empty,
            drawSineWave = empty,
            setClipRect = empty,
            getClipRect = empty,
            setScreenClipRect = empty,
            getScreenClipRect = empty,
            clearClipRect = empty,
            setStencilImage = empty,
            setStencilPattern = empty,
            clearStencil = empty,
            clearStencilImage = empty,
            setImageDrawMode = empty,
            kDrawModeCopy = empty,
            kDrawModeWhiteTransparent = empty,
            kDrawModeBlackTransparent = empty,
            kDrawModeFillWhite = empty,
            kDrawModeFillBlack = empty,
            kDrawModeXOR = empty,
            kDrawModeNXOR = empty,
            kDrawModeInverted = empty,
            getImageDrawMode = empty,
            setLineWidth = empty,
            getLineWidth = empty,
            setStrokeLocation = empty,
            kStrokeCentered = empty,
            kStrokeOutside = empty,
            kStrokeInside = empty,
            getStrokeLocation = empty,
            lockFocus = empty,
            unlockFocus = empty,
            animation = {
               fields = {
                  loop = standards.def_fields("new"),
                  blinker = standards.def_fields("new", "updateAll", "stopAll"),
               }
            },
            animator = standards.def_fields("new"),
            setDrawOffset = empty,
            getDrawOffset = empty,
            getDisplayImage = empty,
            getWorkingImage = empty,
            imagetable = standards.def_fields("new"),
            tilemap = standards.def_fields("new"),
            sprite = standards.def_fields("new", "update", "addSprite", "removeSprite", "setBackgroundDrawingCallback",
               "redrawBackground", "setClipRectsInRange", "setAlwaysRedraw", "getAlwaysRedraw", "addDirtyRect",
               "getAllSprites", "performOnAllSprites", "spriteCount", "removeAll", "removeSprites",
               "allOverlappingSprites", "kCollisionTypeSlide", "kCollisionTypeFreeze", "kCollisionTypeOverlap",
               "kCollisionTypeBounce", "querySpritesAtPoint", "querySpritesInRect", "querySpritesAlongLine",
               "querySpriteInfoAlongLine", "addEmptyCollisionSprite", "addWallSprites"),
            setFont = empty,
            getFont = empty,
            setFontFamily = empty,
            font = standards.def_fields("new", "newFamily", "kVariantNormal", "kVariantBold", "kVariantItalic",
               "kLanguageEnglish", "kLanguageJapanese"),
            setFontTracking = empty,
            getFontTracking = empty,
            getSystemFont = empty,
            drawText = empty,
            drawLocalizedText = empty,
            getLocalizedText = empty,
            getTextSize = empty,
            drawTextAligned = empty,
            drawTextInRect = empty,
            drawLocalizedTextAligned = empty,
            drawLocalizedTextInRect = empty,
            getTextSizeForMaxWidth = empty,
            video = standards.def_fields("new"),
         }
      },

      -- Keyboard
      keyboard = {
         fields = {
            show = empty,
            hide = empty,
            text = read_write,
            setCapitalizationBehavior = empty,
            left = empty,
            width = empty,
            isVisible = empty,
            keyboardDidShowCallback = read_write,
            keyboardDidHideCallback = read_write,
            keyboardWillHideCallback = read_write,
            keyboardAnimatingCallback = read_write,
            textChangedCallback = read_write,
         }
      },

      -- Math
      math = standards.def_fields("lerp"),

      -- Pathfinding
      pathfinder = {
         fields = {
            graph = standards.def_fields("new", "new2DGrid")
         }
      },

      -- Power
      getPowerStatus = empty,
      getBatteryPercentage = empty,
      getBatteryVoltage = empty,

      -- Simulator only
      isSimulator = empty,
      simulator = standards.def_fields("writeToFile", "exit", "getURL"),
      clearConsole = empty,
      setDebugDrawColor = empty,
      keyPressed = read_write,
      keyReleased = read_write,
      debugDraw = read_write,

      -- Sound
      sound = {
         fields = {
            getSampleRate = empty,
            sampleplayer = standards.def_fields("new"),
            fileplayer = standards.def_fields("new"),
            sample = standards.def_fields("new"),
            kFormat8bitMono = empty,
            kFormat8bitStereo = empty,
            kFormat16bitMono = empty,
            kFormat16bitStereo = empty,
            channel = standards.def_fields("new"),
            playingSources = empty,
            synth = standards.def_fields("new"),
            kWaveSine = empty,
            kWaveSquare = empty,
            kWaveSawtooth = empty,
            kWaveTriangle = empty,
            kWaveNoise = empty,
            kWavePOPhase = empty,
            kWavePODigital = empty,
            kWavePOVosim = empty,
            lfo = standards.def_fields("new"),
            kLFOSquare = empty,
            kLFOSawtoothUp = empty,
            kLFOSawtoothDown = empty,
            kLFOTriangle = empty,
            kLFOSine = empty,
            kLFOSampleAndHold = empty,
            envelope = standards.def_fields("new"),
            addEffect = empty,
            removeEffect = empty,
            bitcrusher = standards.def_fields("new"),
            ringmod = standards.def_fields("new"),
            onepolefilter = standards.def_fields("new"),
            twopolefilter = standards.def_fields("new"),
            kFilterLowPass = empty,
            kFilterHighPass = empty,
            kFilterBandPass = empty,
            kFilterNotch = empty,
            kFilterPEQ = empty,
            kFilterLowShelf = empty,
            kFilterHighShelf = empty,
            overdrive = standards.def_fields("new"),
            delayline = standards.def_fields("new"),
            sequence = standards.def_fields("new"),
            track = standards.def_fields("new"),
            instrument = standards.def_fields("new"),
            controlsignal = standards.def_fields("new"),
            micinput = standards.def_fields("recordToSample", "stopRecording", "startListening", "stopListening",
               "getLevel", "getSource"),
            getHeadphoneState = empty,
            setOutputsActive = empty,
            getCurrentTime = empty,
            resetTime = empty,
         }
      },

      -- Strings
      string = standards.def_fields("UUID", "trimWhitespace", "trimLeadingWhitespace", "trimTrailingWhitespace"),

      -- Timers
      timer = standards.def_fields("updateTimers", "new", "performAfterDelay", "keyRepeatTimer",
         "keyRepeatTimerWithDelay", "allTimers"),

      -- Frame timers
      frameTimer = standards.def_fields("updateTimers", "new", "performAfterDelay", "allTimers"),

      -- UI components
      ui = {
         fields = {
            crankIndicator = standards.def_fields("start", "update", "clockwise"),
            gridview = standards.def_fields("new"),
         }
      },

      -- Garbage collection
      setCollectsGarbage = empty,
      setMinimumGCTime = empty,
      setGCScaling = empty,
   }
}

-- vector3d (This isn't part of the playdate namespace so may be beta or unsupported)
local vector3d = standards.def_fields("new")

-- face3d (This isn't part of the playdate namespace so may be beta or unsupported)
local face3d = standards.def_fields("new")

-- shape3d (This isn't part of the playdate namespace so may be beta or unsupported)
local shape3d = standards.def_fields("new")

-- scene3d (This isn't part of the playdate namespace so may be beta or unsupported)
local scene3d = standards.def_fields("new")

return {
   read_globals = {class = class, import = import, Object = Object, playdate = playdate, table = table,
      printTable = printTable, where = where, sample = sample, json = json, kTextAlignment = kTextAlignment,
      vector3d = vector3d, face3d = face3d, shape3d = shape3d, scene3d = scene3d}
}
