class SkyViewPointStatic : SkyViewPoint
{
	Actor base, anchor;
	AlphaLight light;
	double scaling;
	int xoffset, yoffset, zoffset, angleoffset, oldangleoffset;
	bool user_lit, setpos, primary;
	Vector2 oldbaseoffset;

	Default
	{
		//$Category Portal/Skyboxes
		//$Title Skybox ViewPoint (Dynamic)
		//$Arg1 "Skybox Scene Scale"
		//$Arg1Tooltip "The scale of the skybox's scene (default is 100).  The larger this number is, the farther away the skybox contents will appear to be."
		//$Arg1Default 100
		//$Arg2 "Anchor Object TID"
		//$Arg2Tooltip "TID of an actor to anchor the skybox on.  Default value (0) means to anchor on player start spot."
		//$Arg2Default 0
		//$Arg3 "Make this the default sky"
		//$Arg3Tooltip " Should this become the default sky (as if it had no TID)?\nThis allows setting a starting TID on the viewpoint, but still setting the default level sky."
		//$Arg3Type 11
		//$Arg3Enum { 0 = "False"; 1 = "True"; }
		//$Arg3Default 0
		+NOCLIP
		Height 0;
		Radius 0;
	}

	static void SetAnchor(int tid, int anchorid = -1, int baseid = -1)
	{
		if (!tid) { return; }

		ActorIterator it = level.CreateActorIterator(tid, "SkyViewPointStatic");
		SkyViewPointStatic mo = SkyViewPointStatic(it.Next());

		if (!mo)
		{
			console.printf("ERROR: Invalid anchor TID provided to %s.", mo.GetClassName());
			return;
		}

		if (anchorid < 0 && mo.args[2] != 0) { anchorid = mo.args[2]; }

		if (anchorid > 0)
		{
			it = level.CreateActorIterator(anchorid, "Actor");
			mo.anchor = it.Next();
		}

		if (baseid > 0)
		{
			mo.base = null;

			it = level.CreateActorIterator(baseid, "Actor");
			mo.base = it.Next();
		}

		if (!mo.base)
		{
			mo.base = players[consoleplayer].camera;

			if (!mo.base)
			{
				// Iterate through all of the possible players in the game
				for (int i = 0; i < MAXPLAYERS; i++)
				{
					// If a player is in the game and has spawned...
					if (playeringame[i] && players[i].camera)
					{
						if (!mo.base)  // Set the skybox to follow the first player who is in the game
						{
							mo.base = players[i].camera;
						}
						else  // If there are multiple players, don't move the skybox
						{
							mo.base = null;
							break;
						}
					}
				}
			}

			if (mo.base && !mo.anchor)
			{
				mo.anchor = Spawn("SkyViewPointAnchor", mo.base.pos); // Use player's position as a fallback anchor point if no anchor is in place
			}
		}

		if ((mo.tid == 0 && level.sectorPortals[0].mSkybox == null) || mo.args[3] > 0)
		{
			level.sectorPortals[0].mSkybox = mo;
			level.sectorPortals[0].mDestination = mo.CurSector;
			mo.primary = true;
		}
	}

	override void PostBeginPlay()
	{
		// Set the scaling value according to whatever arg 1 value is passed
		scaling = args[1] == 0 ? 100 : args[1];
		scaling *= 1.2;

		// Save the spawn location vector for later
		SpawnPoint = pos;

		if (!tid) { ChangeTID(level.FindUniqueTID()); }

		SetAnchor(tid);

		if (user_lit)
		{
			while (!light) { light = AlphaLight(Spawn("AlphaLight", pos)); }
			light.bAttenuate = true;
			light.master = self;
			light.clr = color("84 84 96");
			light.maxradius = 8 * 100 / args[1];
			light.alpha = 1.0;
		}
	}

	override void Tick()
	{
		Super.Tick();

		if (base && base.player && SpawnPoint != (0, 0, 0))
		{
			Vector2 offset = (base.pos.xy - anchor.pos.xy) / scaling;
			offset = RotateVector(offset, angle + angleoffset);

			Vector2 baseoffset = (xoffset, yoffset) / scaling;
			baseoffset = RotateVector(baseoffset, angle + angleoffset);

			// Set the viewpoint's height location
			double heightdelta = (base.player.viewz - anchor.pos.z) / scaling + zoffset;

			Vector3 dest = (SpawnPoint.xy + offset - baseoffset, SpawnPoint.z + heightdelta);
			double dist = (dest.xy - pos.xy).length();

			if (primary || setpos || base.bTeleport || baseoffset!= oldbaseoffset || angleoffset != oldangleoffset || dist <= 12.0 / scaling)
			{
				SetXYZ(dest);
				setpos = false;
				oldbaseoffset = baseoffset;
				oldangleoffset = angleoffset;
			}
		}

		if (light)
		{
			light.SetXYZ(pos);

			if (base)
			{
				light.alpha = clamp(base.CurSector.lightlevel / 128.0, 0.0, 1.0);
			}
		}
	}
}

class SkyViewpointAnchor : MapSpot
{
	Default
	{
		//$Category Portal/Skyboxes
		//$Title Skybox ViewPoint Anchor
		//$NotAngled
	}
}