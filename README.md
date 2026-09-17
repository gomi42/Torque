# Torque Data Field for the Garmin 1030Plus
### Introduction
This IQ data field displays the torque value on your Garmin 1030Plus. All data field sizes are supported.

![intro](Images/TorqueScreenshot.jpg)

### Garmin Unit Font Emulation
Garmin unfortunately doesn't expose the fonts they use for the units in the API. Special care has been taken to simulate the unit fonts as good as possible. It turned out that Roboto from Google is the perfect starting point. You need to use the BMFont tool anyhow to convert the font into a bitmap font. Some experiments have shown that the emulation is almost perfect with the following settings. The settings are also available in the Roboto directory as configuration files.

![intro](Images/BMFontSettings.jpg)
