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
    public var Baseline as Number;
    // the space above each lowercase char
    public var XHeight as Number;
    public var UppercaseHeight as Number;
    public var LowercaseHeight as Number;
    public var IsUnit as Boolean;

    function initialize(font as FontType, ascent as Number, xHeight as Number, baseline as Number)
    {
        IsUnit = false;
        Font = font;
        Ascent = ascent;
        Baseline = baseline;
        XHeight = xHeight;
        Height = Graphics.getFontHeight(font);
        UppercaseHeight = Baseline - Ascent + 1;
        LowercaseHeight = Baseline - XHeight + 1;
    }
}


// This class bundles all data of a single value and precalculates as much data as possible

class ValueInfo
{
    public var FontInfo as FontDescriptor;
    public var Value as String;
    public var Width as Number;
    public var TopBorder as Number;

    function initialize(FontDescriptor as FontDescriptor)
    {
        Value = "";
        FontInfo = FontDescriptor;
        Width = 0;
        TopBorder = 0;
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

    function setValueUpdate(value as String, dc as Dc) as Void
    {
        Value = value;
        Width = dc.getTextWidthInPixels(Value, FontInfo.Font);
    }

    function update(dc as Dc)
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

    private const UNIT_FONT_SMALL = 1000;
    private const UNIT_FONT_MEDIUM = 1001;
    private const UNIT_FONT_LARGE = 1002;

    // the missing 2 font metric values for each font are determined experimentally
    hidden var FontInfo as Dictionary<Number, FontDescriptor> =
    {
        //Graphics.FONT_XTINY => new FontDescriptor(Graphics.FONT_SYSTEM_XTINY, 5, 7, 0),
        //Graphics.FONT_TINY => new FontDescriptor(Graphics.FONT_SYSTEM_TINY, 5, 8, 0),
        Graphics.FONT_SMALL => new FontDescriptor(Graphics.FONT_SMALL, 4, 8, 20),
        //Graphics.FONT_MEDIUM => new FontDescriptor(Graphics.FONT_MEDIUM, 7, 11, 0),
        //Graphics.FONT_LARGE => new FontDescriptor(Graphics.FONT_LARGE, 10, 17, 0),
        Graphics.FONT_SYSTEM_NUMBER_MEDIUM => new FontDescriptor(Graphics.FONT_SYSTEM_NUMBER_MEDIUM, 2, 0, 36),
        Graphics.FONT_SYSTEM_NUMBER_HOT => new FontDescriptor(Graphics.FONT_SYSTEM_NUMBER_HOT, 3, 0, 48),
        Graphics.FONT_SYSTEM_NUMBER_THAI_HOT => new FontDescriptor(Graphics.FONT_SYSTEM_NUMBER_THAI_HOT, 5, 0, 60),
    };

    //////////////////////////////////////////////////
    // Initialize

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
        
        var font = Application.loadResource(Rez.Fonts.UnitFontSmall);
        FontInfo[UNIT_FONT_SMALL] = new FontDescriptor(font, 6, 9, 19);

        font = Application.loadResource(Rez.Fonts.UnitFontMedium);
        FontInfo[UNIT_FONT_MEDIUM] = new FontDescriptor(font, 8, 13, 27);

        font = Application.loadResource(Rez.Fonts.UnitFontLarge);
        FontInfo[UNIT_FONT_LARGE] = new FontDescriptor(font, 9, 16, 34);

        //labelInfo = new ValueInfo(FontInfo.get(UNIT_FONT_SMALL));
    }

    //////////////////////////////////////////////////
    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.

    function onLayout(dc as Dc) as Void
    {
        // field size | width | height
        // ---------------------------
        // full       | 282   | 470
        // half       | 282   | 234
        // big1       | 282   | 186
        // big2       | 282   | 155
        // medium1    | 282   | 114
        // medium2    | 282   | 93
        // small      | 140   | 93
    
        labelInfo.setValueUpdate(Application.loadResource(Rez.Strings.label), dc);
        unit1Info.setValue("N");
        unit2Info.setValue("m");

        var height = dc.getHeight();

        if (height > 110)
        {
            labelInfo.TopBorder = 2;
            valueInfo.setFontInfo(FontInfo.get(Graphics.FONT_SYSTEM_NUMBER_THAI_HOT), dc);
            unit1Info.setFontInfo(FontInfo.get(UNIT_FONT_LARGE), dc);
            unit2Info.setFontInfo(FontInfo.get(UNIT_FONT_LARGE), dc);
        }
        else
        {
            var width = dc.getWidth();
             
            if (width > 200)
            {
                labelInfo.TopBorder = 2;
                valueInfo.setFontInfo(FontInfo.get(Graphics.FONT_SYSTEM_NUMBER_HOT), dc);
                unit1Info.setFontInfo(FontInfo.get(UNIT_FONT_MEDIUM), dc);
                unit2Info.setFontInfo(FontInfo.get(UNIT_FONT_MEDIUM), dc);
            }
            else
            {
                labelInfo.TopBorder = 3;
                valueInfo.setFontInfo(FontInfo.get(Graphics.FONT_SYSTEM_NUMBER_MEDIUM), dc);
                unit1Info.setFontInfo(FontInfo.get(UNIT_FONT_SMALL), dc);
                unit2Info.setFontInfo(FontInfo.get(UNIT_FONT_SMALL), dc);
            }
        }
    }
        
    //////////////////////////////////////////////////
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
            valueInfo.setValue("_._");
        }
    }

    //////////////////////////////////////////////////
    // Calculate the new average torque and 
    // return a displayable value

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
            return averageTorque.format("%.1f");
        }
        else
        {
            resetAverageTorque();
            return "0.0";
        }
    }

    //////////////////////////////////////////////////
    // Reset the average torque

    function resetAverageTorque() as Void
    {
        torqueSum = 0;
        sampleIndex = 0;
        sampleCount = 0;
    }

    //////////////////////////////////////////////////
    // Simulate some data

    hidden var t1 as Array<Number> = [50, 60, 70, 80, 90, 0, 70, 80, 90, 0, 0];
    hidden var tIndex = 0;
    
    function simulateData() as Void
    {
        var cadence = t1[tIndex];
        tIndex = (tIndex + 1) % t1.size();
        valueInfo.setValue(getDisplayAverageTorque(199, cadence));
    }

    //////////////////////////////////////////////////
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

        valueInfo.update(dc);

        ///////////
        // background

        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle (0, 0, width, height);
    
        ///////////
        // draw label
    
        //dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        //var y = labelInfo.FontInfo.Ascent + labelInfo.TopBorder;
        //dc.drawLine(0, y, width, y);
        //y = labelInfo.FontInfo.XHeight + labelInfo.TopBorder;
        //dc.drawLine(0, y, width, y);
        //y = labelInfo.FontInfo.Height - labelInfo.FontInfo.Descent + labelInfo.TopBorder;
        //dc.drawLine(0, y, width, y);
    
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText((width - labelInfo.Width) / 2, labelInfo.TopBorder, labelInfo.FontInfo.Font, labelInfo.Value, Graphics.TEXT_JUSTIFY_LEFT);

        ///////////
        // calculate value data
    
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
        var unitWidth = unit1Info.Width > unit2Info.Width ? unit1Info.Width : unit2Info.Width;

        //// test lines
        //var yTop3 = yTop;
        //dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        //dc.drawLine(0, yTop3, width, yTop3);
        //dc.drawLine(0, yTop3 + unitHeightNetto1, width, yTop3 + unitHeightNetto1);
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

        dc.drawText(unitX, yTop - unitAscent, unit1Info.FontInfo.Font, unit1Info.Value, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(unitX, yTop + valueHeightNetto - 1 - unit2Info.FontInfo.Baseline, unit2Info.FontInfo.Font, unit2Info.Value, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
