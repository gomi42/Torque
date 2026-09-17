import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application;

class FontInfo
{
    public var Font as FontType;
    public var WinAscent as Number;
    public var Descent as Number;
    public var XHeight as Number;

    function initialize(font as FontType, winAscent as Number, xHeight as Number, descent as Number)
    {
        self.Font = font;
        self.WinAscent = winAscent;
        self.Descent = descent;
        self.XHeight = xHeight;
    }
}

class ValueInfo
{
    public var FontInfos as FontInfo;
    public var Value as String;
    public var Width as Number;
    public var Height as Number;

    function initialize(fontInfo as FontInfo)
    {
        Value = "";
        self.FontInfos = fontInfo;
        self.Width = 0;
        Height = 0;
    }

    function setFontInfo(fontInfo as FontInfo, dc as Dc) as Void
    {
        FontInfos = fontInfo;    
        var dim = dc.getTextDimensions(Value, FontInfos.Font);
        Width = dim[0];
        Height = dim[1];
    }
    
    function setValue(value as String) as Void
    {
        Value = value;
        Width = 0;
        Height = 0;
    }

    function calcDimensions(dc as Dc)
    {
        if (Width == 0)
        {
            var dim = dc.getTextDimensions(Value, FontInfos.Font);
            Width = dim[0];
            Height = dim[1];
        }
    }

    function getUppercaseHeight() as Number
    {
        return Height - FontInfos.WinAscent - FontInfos.Descent;
    }

    function getLowercaseHeight() as Number
    {
        return Height - FontInfos.XHeight - FontInfos.Descent;
    }
}

class TorqueView extends WatchUi.DataField
{
    private var labelInfo as ValueInfo;
    private var valueInfo as ValueInfo;
    private var unit1Info as ValueInfo;
    private var unit2Info as ValueInfo;

    private const SEC_PER_RAD = 60 / (2 * Math.PI);
    private var torqueSamples as Array<Numeric>;
    private var sampleIndex as Number = 0;
    private var sampleCount as Number = 0;
    private var torqueSum as Numeric = 0.0;
    private var averagingCount as Number;

    var unitSmallImage;

    private const  UNIT_FONT_TINY = 1000;
    private const  UNIT_FONT_MEDIUM = 1001;
    private const  UNIT_FONT_LARGE = 1002;

    // the missing 3 font metric values for each font are determined experimentally
    hidden var FontInfos =
    {
        Graphics.FONT_XTINY => new FontInfo(Graphics.FONT_SYSTEM_XTINY, 5, 7, 3),
        Graphics.FONT_TINY => new FontInfo(Graphics.FONT_SYSTEM_TINY, 5, 8, 5),
        Graphics.FONT_SMALL => new FontInfo(Graphics.FONT_SMALL, 6, 10, 5),
        Graphics.FONT_MEDIUM => new FontInfo(Graphics.FONT_MEDIUM, 7, 11, 6),
        Graphics.FONT_LARGE => new FontInfo(Graphics.FONT_LARGE, 10, 17, 10),
        Graphics.FONT_SYSTEM_NUMBER_MILD => new FontInfo(Graphics.FONT_SYSTEM_NUMBER_MILD, 0, 0, 0),
        Graphics.FONT_SYSTEM_NUMBER_MEDIUM => new FontInfo(Graphics.FONT_SYSTEM_NUMBER_MEDIUM, 2, 0, 12),
        Graphics.FONT_SYSTEM_NUMBER_HOT => new FontInfo(Graphics.FONT_SYSTEM_NUMBER_HOT, 2, 0, 17),
        Graphics.FONT_SYSTEM_NUMBER_THAI_HOT => new FontInfo(Graphics.FONT_SYSTEM_NUMBER_THAI_HOT, 4, 0, 20),
    };

    function initialize()
    {
        //System.println("dies ist ein test");
        DataField.initialize();

        averagingCount = Properties.getValue("averagingTime") as Number;
        torqueSamples = new Array<Numeric>[averagingCount];

        labelInfo = new ValueInfo(FontInfos.get(Graphics.FONT_SMALL));
        valueInfo = new ValueInfo(FontInfos.get(Graphics.FONT_SMALL));
        unit1Info = new ValueInfo(FontInfos.get(Graphics.FONT_SMALL));
        unit2Info = new ValueInfo(FontInfos.get(Graphics.FONT_SMALL));
        
        var font = Application.loadResource(Rez.Fonts.RobotoSmall);
        FontInfos[UNIT_FONT_TINY] = new FontInfo(font, 6, 9, 5);

        font = Application.loadResource(Rez.Fonts.RobotoMedium);
        FontInfos[UNIT_FONT_MEDIUM] = new FontInfo(font, 7, 13, 7);

        font = Application.loadResource(Rez.Fonts.RobotoLarge);
        FontInfos[UNIT_FONT_LARGE] = new FontInfo(font, 8, 16, 10);

        //labelInfo = new ValueInfo(FontInfos.get(UNIT_FONT_LARGE));

        //unitSmallImage = Application.loadResource( Rez.Drawables.UnitSmall ) as BitmapResource;
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc as Dc) as Void
    {
        // field size | width | height
        // ---------------------------
        // big        | 282   | 186
        // medium1    | 282   | 114
        // medium2    | 282   | 93
        // small      | 140   | 93
    
        labelInfo.setValue(Application.loadResource(Rez.Strings.label));
        unit1Info.setValue("N");
        unit2Info.setValue("m");

        var height = dc.getHeight();

        if (height > 110)
        {
            valueInfo.setFontInfo(FontInfos.get(Graphics.FONT_SYSTEM_NUMBER_THAI_HOT), dc);
            unit1Info.setFontInfo(FontInfos.get(UNIT_FONT_LARGE), dc);
            unit2Info.setFontInfo(FontInfos.get(UNIT_FONT_LARGE), dc);
        }
        else
        {
            var width = dc.getWidth();
             
            if (width > 200)
            {
                valueInfo.setFontInfo(FontInfos.get(Graphics.FONT_SYSTEM_NUMBER_HOT), dc);
                unit1Info.setFontInfo(FontInfos.get(UNIT_FONT_MEDIUM), dc);
                unit2Info.setFontInfo(FontInfos.get(UNIT_FONT_MEDIUM), dc);
            }
            else
            {
                valueInfo.setFontInfo(FontInfos.get(Graphics.FONT_SYSTEM_NUMBER_MEDIUM), dc);
                unit1Info.setFontInfo(FontInfos.get(UNIT_FONT_TINY), dc);
                unit2Info.setFontInfo(FontInfos.get(UNIT_FONT_TINY), dc);
            }
        }
    }
        
    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void
    {
        //simulateData();
        //return;

        if (info has :currentCadence 
            && info has :currentPower
            && info.currentCadence != null
            && info.currentPower != null)
        {
            valueInfo.setValue(getDisplayAverageTorque(info.currentPower, info.currentCadence));
        }
        else
        {
            resetAverageTorque();
            valueInfo.setValue("--");
        }
    }

    function getDisplayAverageTorque(power as Numeric, cadence as Numeric) as String
    {
        if (cadence > 0)
        {
            var torque = power * SEC_PER_RAD / cadence;
        
            if (sampleCount < averagingCount)
            {
                torqueSamples[sampleIndex] = torque;
                sampleCount++;
            }
            else
            {
                torqueSum -= torqueSamples[sampleIndex];
                torqueSamples[sampleIndex] = torque;
            }
    
            torqueSum += torque;
            sampleIndex = (sampleIndex + 1) % averagingCount;
            
            var averageTorque = torqueSum / sampleCount;
            return Math.round(averageTorque).format("%u");
        }
        else
        {
            resetAverageTorque();
            return "0";
        }
    }

    function resetAverageTorque() as Void
    {
        torqueSum = 0;
        sampleIndex = 0;
        sampleCount = 0;
    }

    hidden var t1 = [50, 60, 70, 80, 90, 0, 70, 80, 90, 0, 0];
    hidden var tIndex = 0;
    
    function simulateData() as Void
    {
        var cadence = t1[tIndex];
        tIndex = (tIndex + 1) % t1.size();
        valueInfo.setValue(getDisplayAverageTorque(200, cadence));
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc as Dc) as Void
    {
        var backgroundColor = getBackgroundColor();
        var foregroundColor;
        
        if (backgroundColor == Graphics.COLOR_BLACK)
        {
            foregroundColor = Graphics.COLOR_WHITE;
        }
        else
        {
            foregroundColor = Graphics.COLOR_BLACK;
        }

        ///////////

        var width = dc.getWidth();
        var height = dc.getHeight();
 
        ///////////
        // background

        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle (0, 0, width, height);
    
        ///////////
        // draw label
    
        labelInfo.calcDimensions(dc);
        valueInfo.calcDimensions(dc);
        unit1Info.calcDimensions(dc);
        unit2Info.calcDimensions(dc);

        //dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        //var y = labelInfo.FontInfos.WinAscent;
        //dc.drawLine(0, y, width, y);
        //y = labelInfo.FontInfos.XHeight;
        //dc.drawLine(0, y, width, y);
        //y = labelInfo.Height - labelInfo.FontInfos.Descent;
        //dc.drawLine(0, y, width, y);
    
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText((width - labelInfo.Width) / 2, 0, labelInfo.FontInfos.Font, labelInfo.Value, Graphics.TEXT_JUSTIFY_LEFT);

        ///////////
        // calculate value data
    
        // test lines
        //var metric42 = FontInfos.get(labelFont);
        //dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        //dc.drawLine(0, metric42.XHeight, width, metric42.XHeight);
        //dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        // Ende

        var valueWinAscent = valueInfo.FontInfos.WinAscent;
        
        var labelHeightNetto = labelInfo.getUppercaseHeight() + labelInfo.FontInfos.WinAscent;
        var valueHeightNetto = valueInfo.getUppercaseHeight();

        var gap = (height - labelHeightNetto - valueHeightNetto) / 2;
        var yTop = labelHeightNetto + gap + 3;

        // test lines
        //var yTop2 = yTop;
        //var yBottom = yTop2 + valueHeightNetto;
        //dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        //dc.drawLine(0, yTop2, width, yTop2);
        //dc.drawLine(0, yBottom, width, yBottom);
        //dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        // Ende

        /////////////
        // calculate unit data

        var unitWinAscent = unit1Info.FontInfos.WinAscent;
        var unitHeightNetto1 = unit1Info.getUppercaseHeight();
        var unitHeightNetto2 = unit1Info.getLowercaseHeight();

        var unitWidth = unit1Info.Width > unit2Info.Width ? unit1Info.Width : unit2Info.Width;

        var unitSumHeight = unitHeightNetto1 + unitHeightNetto2 + unitWinAscent;
        var heightGap = (valueHeightNetto - unitSumHeight);
        var unitY = yTop + heightGap;

        //// test lines
        //dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        //dc.drawLine(0, unitY, width, unitY);
        //dc.drawLine(0, unitY + unitHeightNetto1, width, unitY + unitHeightNetto1);
        //dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        // Ende

        /////////////
        // draw value
       
        var valueUnitGapX = 2;

        var horzGap = (width - valueInfo.Width - unitWidth  + valueUnitGapX) / 2;
        dc.drawText(horzGap, yTop - valueWinAscent, valueInfo.FontInfos.Font, valueInfo.Value, Graphics.TEXT_JUSTIFY_LEFT);

        /////////////
        // draw unit

        var unitX = horzGap + valueInfo.Width + valueUnitGapX;

        // it looks better when moving the chars 1 pixel up/down
        dc.drawText(unitX, yTop - unit1Info.FontInfos.WinAscent + 1, unit1Info.FontInfos.Font, unit1Info.Value, Graphics.TEXT_JUSTIFY_LEFT);
        // it looks better when moving this char 1 pixel up
        dc.drawText(unitX, unitY + unitHeightNetto1 - unit2Info.FontInfos.XHeight + unitWinAscent - 1, unit2Info.FontInfos.Font, unit2Info.Value, Graphics.TEXT_JUSTIFY_LEFT);
        //dc.drawBitmap(unitX,  yTop, unitSmallImage);
    }
}
