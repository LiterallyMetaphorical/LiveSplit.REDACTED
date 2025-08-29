    state("Redacted-Win64-Shipping"){ }

    startup
    {
        Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
		vars.Helper.GameName = "REDACTED";
		vars.Helper.AlertLoadless();

		#region setting creation
		//Autosplitter Settings Creation
		dynamic[,] _settings =
		{
        {"Splits Options", 				true, "Splits Options [SELECT ONE ONLY]",				null},
            {"Room Splits",             true, "Room Splits",                                "Splits Options"},
            {"Area Splits",             true, "Area Splits",                                "Splits Options"},
		{"GameInfo", 					true, "Print Various Game Info",						null},
			{"Map",                     true, "Current Map",                                "GameInfo"},
            {"IGT",                     false, "Current IGT",                                "GameInfo"},
            {"Total Room Counter",      true, "Total Room Counter",                                "GameInfo"},
            {"Total Biome Counter",      true, "Total Biome Counter",                                "GameInfo"},
		};
		vars.Helper.Settings.Create(_settings);
		#endregion

		#region TextComponent
		vars.lcCache = new Dictionary<string, LiveSplit.UI.Components.ILayoutComponent>();
		vars.SetText = (Action<string, object>)((text1, text2) =>
		{
			const string FileName = "LiveSplit.Text.dll";
			LiveSplit.UI.Components.ILayoutComponent lc;

			if (!vars.lcCache.TryGetValue(text1, out lc))
			{
				lc = timer.Layout.LayoutComponents.Reverse().Cast<dynamic>()
					.FirstOrDefault(llc => llc.Path.EndsWith(FileName) && llc.Component.Settings.Text1 == text1)
					?? LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent(FileName, timer);

				vars.lcCache.Add(text1, lc);
			}

			if (!timer.Layout.LayoutComponents.Contains(lc)) timer.Layout.LayoutComponents.Add(lc);
			dynamic tc = lc.Component;
			tc.Settings.Text1 = text1;
			tc.Settings.Text2 = text2.ToString();
		});
		vars.RemoveText = (Action<string>)(text1 =>
		{
			LiveSplit.UI.Components.ILayoutComponent lc;
			if (vars.lcCache.TryGetValue(text1, out lc))
			{
				timer.Layout.LayoutComponents.Remove(lc);
				vars.lcCache.Remove(text1);
			}
		});
		#endregion

        //Creating a room counter variable
        vars.totalRoomCount = 0;
        vars.biomeRoomCount = 0;
    }

    init
    {
    	IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
        IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
        IntPtr fNamePool = vars.Helper.ScanRel(3, "48 8d 05 ???????? eb ?? 48 8d 0d ???????? e8 ???????? c6 05");
        IntPtr gSyncLoadCount = vars.Helper.ScanRel(5, "89 43 60 8B 05 ?? ?? ?? ??");
        IntPtr IGTPtr = vars.Helper.ScanRel(3, "48 8B ?? ?? ?? ?? ?? C3 ?? ?? ?? ?? ?? ?? ?? ?? 48 83 ?? ?? 48 8B ?? ?? ?? ?? ?? 48 85 ?? 74 ?? 48 8B ?? ?? ?? ?? ?? 48 85");
		
		if (gWorld == IntPtr.Zero || gEngine == IntPtr.Zero || fNamePool == IntPtr.Zero)
		{
			const string Msg = "Not all required addresses could be found by scanning... yet";
			throw new Exception(Msg);
		}

		// GWorld.FNameIndex
		vars.Helper["IGT"] = vars.Helper.Make<int>(IGTPtr, 0x228);
        // GWorld.FNameIndex
		vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);

        //FName Reader (define before RefreshNames)
	    vars.FNameToString = (Func<ulong, string>)(fName =>
		{
			var nameIdx = (fName & 0x000000000000FFFF) >> 0x00;
			var chunkIdx = (fName & 0x00000000FFFF0000) >> 0x10;
			var number = (fName & 0xFFFFFFFF00000000) >> 0x20;

			IntPtr chunk = vars.Helper.Read<IntPtr>(fNamePool + 0x10 + (int)chunkIdx * 0x8);
			IntPtr entry = chunk + (int)nameIdx * sizeof(short);

			int length = vars.Helper.Read<short>(entry) >> 6;
			string name = vars.Helper.ReadString(length, ReadStringType.UTF8, entry + sizeof(short));

			return number == 0 ? name : name + "_" + number;
		});
    
        vars.RefreshFNames = (Action)(() =>
        {
            current.World = vars.FNameToString(current.GWorldName);
        });

		vars.SetTextIfEnabled = (Action<string, object>)((text1, text2) =>
		{
			if (settings[text1]) vars.SetText(text1, text2); 
			else vars.RemoveText(text1);
		});

        vars.Helper.Update();
		vars.Helper.MapPointers();
        ((Action)vars.RefreshFNames)();
    }

    update
    {
        vars.Helper.Update();
		vars.Helper.MapPointers();
        ((Action)vars.RefreshFNames)();

        //incrementing the Room Counter by 1 each time we detect a room change
        if(old.World != current.World)
        {
            ++ vars.totalRoomCount; //incrementing the Room Counter by 1 each time we detect a room change
            
            if(old.World.Contains("Exit_Persistent") && current.World.Contains("Start_Persistent")) 
            { vars.biomeRoomCount = 1; } 
            else 
            { ++ vars.biomeRoomCount; }
        }

        vars.SetTextIfEnabled("Map",current.World);
        vars.SetTextIfEnabled("IGT",current.IGT);
        vars.SetTextIfEnabled("Total Room Counter",vars.totalRoomCount);
		vars.SetTextIfEnabled("Total Biome Counter",vars.biomeRoomCount);

        //vars.Log(current.IGT);
    }

    start
    {
        return old.World != "PRS_FirstRoom_Persistent" && current.World == "PRS_FirstRoom_Persistent";
    }

    onStart
    {
        vars.totalRoomCount = 1;
        vars.biomeRoomCount = 1;
    }

    split 
    { 	
        if ((settings["Area Splits"] && old.World.Contains("Exit_Persistent") && current.World.Contains("Start_Persistent")) || (settings["Room Splits"] && old.World != current.World))
        {
            return true;
        }
        return false;
    }

    reset
    {
        return current.World == "PRS_Start_Persistent" && old.World != "PRS_Start_Persistent";
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
