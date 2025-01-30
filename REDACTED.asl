/*
Scanning Best Practices:

string500 map search for a string with UTF-16 ticked, "/Game/Maps/Game/BEV_OUTBREAK" (first area) full string should be something like /Game/Maps/Game/BEV_Outbreak/PRS_Start_Persistent
end offsets should be 0x30, 0x30, 0x0. Region of memory should be 06

IGT search for a 4Byte matching the in-game time, its really that easy lol
One offset, 0x228 - region of memory is 06
*/

state("Redacted-Win64-Shipping")
{
    string500 map: 0x06AFA108, 0x1A0, 0x30, 0x30, 0x0;
    int IGT      : 0x06D31CB8, 0x228;
}

startup
  {
    //Creating a room counter variable
    vars.totalRoomCount = 0;
    vars.biomeRoomCount = 0;

	//Checks if the current time method is Real Time, if it is then it spawns a popup asking to switch to Game Time
    if (timer.CurrentTimingMethod == TimingMethod.RealTime)
    {
        var timingMessage = MessageBox.Show (
            "This game uses Time without Loads (Game Time) as the main timing method.\n"+
            "LiveSplit is currently set to show Real Time (RTA).\n"+
            "Would you like to set the timing method to Game Time?",
            "LiveSplit | REDACTED",
            MessageBoxButtons.YesNo,MessageBoxIcon.Question
        );

        if (timingMessage == DialogResult.Yes)
        {
            timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
    }

    //creates text components for variable information
	vars.SetTextComponent = (Action<string, string>)((id, text) =>
	{
	        var textSettings = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent").Select(x => x.GetType().GetProperty("Settings").GetValue(x, null));
	        var textSetting = textSettings.FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == id);
	        if (textSetting == null)
	        {
	        var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
	        var textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
	        timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));
	
	        textSetting = textComponent.GetType().GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public).GetValue(textComponent, null);
	        textSetting.GetType().GetProperty("Text1").SetValue(textSetting, id);
	        }
	
	        if (textSetting != null)
	        textSetting.GetType().GetProperty("Text2").SetValue(textSetting, text);
    });

    //Optional Room Splits
    //Parent setting
    settings.Add("Splits Options", true, "Splits Options [SELECT ONE ONLY]");
    //Child Settings
    settings.Add("Room Splits", false, "Room Splits", "Splits Options");
    settings.Add("Area Splits", true, "Area Splits", "Splits Options");
    //Creating actual text stuff
    //Parent setting
	settings.Add("Variable Information", true, "Variable Information");
	//Child settings that will sit beneath Parent setting
    settings.Add("Total Room Counter", true, "Total Room Counter", "Variable Information");
    settings.Add("Biome Room Counter", true, "Biome Room Counter", "Variable Information");
    settings.Add("Current Map", true, "Current Map", "Variable Information");
    

    
}

update
{
    //cutting the first 16 characters off the string value for a prettier name to work with
    current.mapPretty = current.map.ToString().Substring(16);

    //incrementing the Room Counter by 1 each time we detect a room change
    if(old.map != current.map){
        ++ vars.totalRoomCount;
        //incrementing the Room Counter by 1 each time we detect a room change
        if(old.map.Contains("Exit_Persistent") && current.map.Contains("Start_Persistent")) {
            vars.biomeRoomCount = 1;
        } else {
            ++ vars.biomeRoomCount;
        }
    }
    
    //Prints room count
    if(settings["Total Room Counter"]){vars.SetTextComponent("Total Room Count: ",vars.totalRoomCount.ToString());}

    //Prints room count
    if(settings["Biome Room Counter"]){vars.SetTextComponent("Biome Room Count: ",vars.biomeRoomCount.ToString());}

    //Prints Current Map
    if(settings["Current Map"]){vars.SetTextComponent("",current.mapPretty);}
    
}

onStart
{
    vars.totalRoomCount = 1;
    vars.biomeRoomCount = 1;
}

start
{
    return old.map == "/Game/Maps/Game/BEV_Outbreak/PRS_Start_Persistent" && current.map == "/Game/Maps/Game/BEV_Outbreak/PRS_FirstRoom_Persistent";
}

split 
{ 	
    if ((settings["Area Splits"] && old.map.Contains("Exit_Persistent") && current.map.Contains("Start_Persistent")) || (settings["Room Splits"] && old.map != current.map))
    {
        return true;
    }
    return false;
}

reset
{
    return current.map == "/Game/Maps/Game/BEV_Outbreak/PRS_Start_Persistent" && old.map != "/Game/Maps/Game/BEV_Outbreak/PRS_Start_Persistent";
}

onReset
{
    vars.totalRoomCount = 0;
    vars.biomeRoomCount = 0;
}

gameTime 
{
    return TimeSpan.FromSeconds(current.IGT);
}

//Game/Maps/Game/BEV_Outbreak
//Game/Maps/Game/BEV_Hydro
//Game/Maps/Game/BEV_Snowcat
//Game/Maps/Game/BEV_Hangar
