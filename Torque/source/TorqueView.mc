import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application;

// The class adds some more infos about a font and precalculates some values

class FontDescriptor
{
    public var Font as FontType;
    // the height including all spaces above and below the printable height
    public var Height as Number;
    // the empty space above each uppercase char
    public var Ascent as Number;
    // space below the baseline
    public var Descent as Number;
    // the space above each lowercase char
    public var XHeight as Number;
    public var UppercaseHeight as Number;
    public var LowercaseHeight as Number;

    function initialize(font as FontType, ascent as Number, xHeight as Number)
    {
        Font = font;
        Ascent = ascent;
        Descent = Graphics.getFontDescent(font);
        XHeight = xHeight;
        Height = Graphics.getFontHeight(font);
        UppercaseHeight = Height - Ascent - Descent;
        LowercaseHeight = Height - XHeight - Descent;
    }
}

// The main purpose of this class is to buffer the with of the value, so that
// the expensive call to getTextWidthInPixels isn't called each time in onUpdate()

class ValueInfo
{
    public var FontInfo as FontDescriptor;
    public var Value as String;
    public var Width as Number;

    function initialize(FontDescriptor as FontDescriptor)
    {
        Value = "";
        FontInfo = FontDescriptor;
        Width = 0;
    }

    function setFontInfo(FontDescriptor as FontDescriptor, dc as Dc) as Void
    {
        FontInfo = FontDescriptor;    
        Width = dc.getTextWidthInPixels(Value, FontInfo.Font);
    }
    
    function setValue(value as String) as Void
    {
        Value = value;
        Width = 0;
    }

    function calcDimensions(dc as Dc)
    {
        if (Width == 0)
        {
            Width = dc.getTextWidthInPixels(Value, FontInfo.Font);
        }
    }
}

// The DataField implementation

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

    // the missing 2 font metric values for each font are determined experimentally
    hidden var FontInfo =
    {
        Graphics.FONT_XTINY => new FontDescriptor(Graphics.FONT_SYSTEM_XTINY, 5, 7),
        Graphics.FONT_TINY => new FontDescriptor(Graphics.FONT_SYSTEM_TINY, 5, 8),
        Graphics.FONT_SMALL => new FontDescriptor(Graphics.FONT_SMALL, 6, 10),
        Graphics.FONT_MEDIUM => new FontDescriptor(Graphics.FONT_MEDIUM, 7, 11),
        Graphics.FONT_LARGE => new FontDescriptor(Graphics.FONT_LARGE, 10, 17),
        Graphics.FONT_SYSTEM_NUMBER_MILD => new FontDescriptor(Graphics.FONT_SYSTEM_NUMBER_MILD, 0, 0),
        Graphics.FONT_SYSTEM_NUMBER_MEDIUM => new FontDescriptor(Graphics.FONT_SYSTEM_NUMBER_MEDIUM, 2, 0),
        Graphics.FONT_SYSTEM_NUMBER_HOT => new FontDescriptor(Graphics.FONT_SYSTEM_NUMBER_HOT, 2, 0),
        Graphics.FONT_SYSTEM_NUMBER_THAI_HOT => new FontDescriptor(Graphics.FONT_SYSTEM_NUMBER_THAI_HOT, 4, 0),
    };

    function initialize()
    {
        //System.println("dies ist ein test");
        DataField.initialize();

        averagingCount = Properties.getValue("averagingTime") as Number;
        torqueSamples = new Array<Numeric>[averagingCount];

        labelInfo = new ValueInfo(FontInfo.get(Graphics.FONT_SMALL));
        valueInfo = new ValueInfo(FontInfo.get(Graphics.FONT_SMALL));
        unit1Info = new ValueInfo(FontInfo.get(Graphics.FONT_SMALL));
        unit2Info = new ValueInfo(FontInfo.get(Graphics.FONT_SMALL));
        
        var font = Application.loadResource(Rez.Fonts.RobotoSmall);
        FontInfo[UNIT_FONT_TINY] = new FontDescriptor(font, 6, 9);

        font = Application.loadResource(Rez.Fonts.RobotoMedium);
        FontInfo[UNIT_FONT_MEDIUM] = new FontDescriptor(font, 7, 13);

        font = Application.loadResource(Rez.Fonts.RobotoLarge);
        FontInfo[UNIT_FONT_LARGE] = new FontDescriptor(font, 8, 16);

        //labelInfo = new ValueInfo(FontInfo.get(UNIT_FONT_LARGE));
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
            valueInfo.setFontInfo(FontInfo.get(Graphics.FONT_SYSTEM_NUMBER_THAI_HOT), dc);
            unit1Info.setFontInfo(FontInfo.get(UNIT_FONT_LARGE), dc);
            unit2Info.setFontInfo(FontInfo.get(UNIT_FONT_LARGE), dc);
        }
        else
        {
            var width = dc.getWidth();
             
            if (width > 200)
            {
                valueInfo.setFontInfo(FontInfo.get(Graphics.FONT_SYSTEM_NUMBER_HOT), dc);
                unit1Info.setFontInfo(FontInfo.get(UNIT_FONT_MEDIUM), dc);
                unit2Info.setFontInfo(FontInfo.get(UNIT_FONT_MEDIUM), dc);
            }
            else
            {
                valueInfo.setFontInfo(FontInfo.get(Graphics.FONT_SYSTEM_NUMBER_MEDIUM), dc);
                unit1Info.setFontInfo(FontInfo.get(UNIT_FONT_TINY), dc);
                unit2Info.setFontInfo(FontInfo.get(UNIT_FONT_TINY), dc);
            }
        }
    }
        
    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void
    {
        simulateData();
        return;

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
            valueInfo.setValue("__");
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
        //var y = labelInfo.FontInfo.Ascent;
        //dc.drawLine(0, y, width, y);
        //y = labelInfo.FontInfo.XHeight;
        //dc.drawLine(0, y, width, y);
        //y = labelInfo.Height - labelInfo.FontInfo.Descent;
        //dc.drawLine(0, y, width, y);
    
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText((width - labelInfo.Width) / 2, 0, labelInfo.FontInfo.Font, labelInfo.Value, Graphics.TEXT_JUSTIFY_LEFT);

        ///////////
        // calculate value data
    
        // test lines
        //var metric42 = FontInfo.get(labelFont);
        //dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        //dc.drawLine(0, metric42.XHeight, width, metric42.XHeight);
        //dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        // Ende

        var valueAscent = valueInfo.FontInfo.Ascent;
        
        var labelHeightNetto = labelInfo.FontInfo.UppercaseHeight + labelInfo.FontInfo.Ascent;
        var valueHeightNetto = valueInfo.FontInfo.UppercaseHeight;

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

        var unitAscent = unit1Info.FontInfo.Ascent;
        var unitHeightNetto1 = unit1Info.FontInfo.UppercaseHeight;
        var unitHeightNetto2 = unit1Info.FontInfo.LowercaseHeight;

        var unitWidth = unit1Info.Width > unit2Info.Width ? unit1Info.Width : unit2Info.Width;

        var unitSumHeight = unitHeightNetto1 + unitHeightNetto2 + unitAscent;
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
        dc.drawText(horzGap, yTop - valueAscent, valueInfo.FontInfo.Font, valueInfo.Value, Graphics.TEXT_JUSTIFY_LEFT);

        /////////////
        // draw unit

        var unitX = horzGap + valueInfo.Width + valueUnitGapX;

        // it looks better when moving the chars 1 pixel up/down
        dc.drawText(unitX, yTop - unit1Info.FontInfo.Ascent + 1, unit1Info.FontInfo.Font, unit1Info.Value, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(unitX, unitY + unitHeightNetto1 - unit2Info.FontInfo.XHeight + unitAscent - 1, unit2Info.FontInfo.Font, unit2Info.Value, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
