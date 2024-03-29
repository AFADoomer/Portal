// Light that scales in size according to the value passed as the alpha amount
class AlphaLight : DynamicLight
{
	Color clr;
	double maxradius;
	Vector3 spawnoffset, oldpos;
	int flickertime;
	double oldangle, oldpitch, oldroll;

	Property LightColor:clr;
	Property LightRadius:maxradius;

	Default
	{
		DynamicLight.Type "Point";
		AlphaLight.LightColor 0xFFFFFF;
		AlphaLight.LightRadius 16;
	}

	override void BeginPlay ()
	{
		alpha = 0;

		args[LIGHT_RED] = clr.r;
		args[LIGHT_GREEN] = clr.g;
		args[LIGHT_BLUE] = clr.b;
		args[LIGHT_INTENSITY] = int(maxradius * scale.y * alpha);

		ChangeStatNum(Thinker.STAT_USER + 3);

		Super.BeginPlay();
	}

	override void PostBeginPlay()
	{
		bDormant = SpawnFlags & MTF_DORMANT;

		if (master)
		{
			spawnoffset = pos - master.pos;

			Vector2 temp = RotateVector((spawnoffset.x, spawnoffset.y), -master.angle);
			spawnoffset = (temp.x, temp.y, spawnoffset.z);

			if (master is "AttenuatedAlphaLight")
			{
				maxradius = AlphaLight(master).maxradius / 4;
				angle = master.angle;
			}

			oldpos = master.pos;
			oldangle = master.angle;
			oldpitch = master.pitch;
			oldroll = master.roll;
		}

		Super.PostBeginPlay();

		CVar debug = Cvar.FindCVar("g_debuglights");

		if (debug && debug.GetBool()) { FlatText.SpawnString(self, String.Format("%i", maxradius), (master is "AttenuatedAlphaLight") ? 0x555500 : clr); }
	}

	override void Tick()
	{
		Super.Tick();

		if (IsFrozen()) { return; }

		if (master is "AttenuatedAlphaLight")
		{
			clr.r = AlphaLight(master).clr.r / 16;
			clr.g = AlphaLight(master).clr.g / 16;
			clr.b = AlphaLight(master).clr.b / 16;

			alpha = master.alpha * 10.0;

			args[LIGHT_INTENSITY] = min(32, AlphaLight(master).args[LIGHT_INTENSITY] / 4);
		}
		else
		{
			args[LIGHT_INTENSITY] = int(maxradius * scale.y * alpha * !bDormant);
		}

		args[LIGHT_RED] = int(clr.r * alpha);
		args[LIGHT_GREEN] = int(clr.g * alpha);
		args[LIGHT_BLUE] = int(clr.b * alpha);

		if (master && spawnoffset != (0, 0, 0)) { Rotate(); }
	}

	void Rotate()
	{
		if (master && (oldpos == master.pos && oldangle == master.angle && oldpitch == master.pitch && oldroll == master.roll)) { return; }

		Vector2 temp = RotateVector((spawnoffset.y, spawnoffset.z), master.roll);
		Vector3 offset = (spawnoffset.x, temp.x, temp.y);

		temp = RotateVector((offset.x, offset.z), 360 - master.pitch);
		offset = (temp.x, offset.y, temp.y);

		temp = RotateVector((offset.x, offset.y), master.angle);
		offset = (temp.x, temp.y, offset.z);

		offset.x *= master.scale.x;
		offset.y *= master.scale.x;
		offset.z *= master.scale.y;

		SetOrigin(master.pos + offset, true);

		oldpos = master.pos;
		oldangle = master.angle;
		oldpitch = master.pitch;
		oldroll = master.roll;
	}

	override void Activate(Actor activator)
	{
		if (master && master is "AttenuatedAlphaLight")
		{
			if (level.time > 5)
			{
				Super.Activate(activator);
			}
		}
		else
		{
			Super.Activate(activator);
		}
	}
}

class AttenuatedAlphaLight : AlphaLight replaces PointLightAttenuated
{
	double user_lightlevel;
	AlphaLight base;

	Default
	{
		//$Sprite internal:Light
		+DYNAMICLIGHT.ATTENUATE
		DynamicLight.SpotOuterAngle 70;
	}

	override void BeginPlay()
	{
		clr.r = args[LIGHT_RED];
		clr.g = args[LIGHT_GREEN];
		clr.b = args[LIGHT_BLUE];
		maxradius = args[LIGHT_INTENSITY];

		Super.BeginPlay();
	}

	override void PostBeginPlay()
	{
		bSpot = true;
		SpotInnerAngle = 1;

		if (!master)
		{
			if (!user_lightlevel) { user_lightlevel = 10.0; }

			base = AlphaLight(Spawn("AlphaLight", pos));
			if (base) { base.master = self; }
		}
		else if (master is "LightSpawner")
		{
			base = AlphaLight(Spawn("AlphaLight", pos));
			if (base) { base.master = self; }
		}

		if (!user_lightlevel) { user_lightlevel = 5.0; }

		Super.PostBeginPlay();

		alpha = user_lightlevel;
		scale.y = scale.y / user_lightlevel;
	}

	override void Tick()
	{
		if (IsFrozen())
		{
			if (flickertime) { flickertime++; }
			return;
		}

		Super.Tick();

		if (!flickertime && !bDormant && !tid)
		{
			if (Distance2D(players[consoleplayer].mo) < 196.0) { Activate(self); }
		}

		if (level.time < flickertime)
		{
			args[LIGHT_INTENSITY] = (flickertime - level.time > 35) ? 0 : Random(int(maxradius / 4), int(maxradius));
		}
		else
		{
			args[LIGHT_INTENSITY] = int(maxradius);
		}

		if (!master && pitch == 90)
		{
			// Change ceiling brightness directly
//			curSector.SetPlaneLight(Sector.ceiling, args[LIGHT_INTENSITY]);
		}
	}

	override void Activate(Actor activator)
	{
		if ((!master || master is "LightSpawner"))
		{
			if (level.time > 35)
			{
				flickertime = level.time + Random(15, 45);

				if (flickertime > level.time + 35 && Random(0, 2)) { A_StartSound("lights/flicker", CHAN_AUTO, 0, FRandom(0.125, 0.25), ATTN_NORM, FRandom(0.8, 1.2)); }

				Super.Activate(activator);
				if (base) { base.Activate(self); }
			}
			else if (LightSpawner(master) && LightSpawner(master).user_active)
			{
				flickertime = level.time + 1;
				Super.Activate(activator);
				if (base) { base.Activate(self); }
			}
		}
		else
		{
			Super.Activate(activator);
		}
	}

	override void Deactivate(Actor activator)
	{
		if (base) { base.Deactivate(self); }

		Super.Deactivate(activator);
	}
}

class LightSpawner : Actor
{
	Line linedef;
	double linelength;
	int user_rows, user_cols, user_rowsize, user_colsize, user_maxradius;
	bool user_active;

	Default
	{
		//$Category Portal/Utilities
		//$Title Light Spawner
		//$Sprite LISPA0
		+NOINTERACTION
		+INVISIBLE
		+WALLSPRITE
		Height 1;
		Radius 3;
	}

	States
	{
		Spawn:
			UNKN A 1;
			UNKN A -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		linedef = GetClosestLine();

		if (!linedef)
		{
			Destroy(); 
			return;
		}

		TextureID tex;

		if (user_rows && user_cols && user_rowsize && user_colsize)
		{
			Utilities.SpawnLights(self, user_rows, user_cols, user_rowsize, user_colsize, user_active);
		}
		else if (linedef.sidedef[0] && !linedef.sidedef[1]) { DoLights(linedef.sidedef[0].GetTexture(Side.mid)); }
		else if (linedef.sidedef[1] && !linedef.sidedef[0]) { DoLights(linedef.sidedef[1].GetTexture(Side.mid)); }
		else
		{
			for (int i = 0; i < 3; i++)
			{
				if (linedef.sidedef[0])
				{
					DoLights(linedef.sidedef[0].GetTexture(i), linedef.backsector.LowestFloorAt(pos.xy - RotateVector((-4.0, 0), angle)), linedef.backsector.HighestCeilingAt(pos.xy - RotateVector((-4.0, 0), angle)));
				}
	
				if (linedef.sidedef[1])
				{
					DoLights(linedef.sidedef[1].GetTexture(i), linedef.frontsector.LowestFloorAt(pos.xy - RotateVector((-4.0, 0), angle)), linedef.frontsector.HighestCeilingAt(pos.xy - RotateVector((-4.0, 0), angle)));
				}
			}
		}

		Super.PostBeginPlay();
	}

	Line GetClosestLine()
	{
		// Find the line that this actor's centerpoint is closest to
		Line linedef;
		double dist;

		BlockLinesIterator it = BlockLinesIterator.Create(self);

		While (it.Next())
		{
			Line current = it.curline;

			// Discard lines that definitely don't cross the actor's center point
			if (
				(current.v1.p.x > pos.x + radius && current.v2.p.x > pos.x + radius) ||
				(current.v1.p.x < pos.x - radius && current.v2.p.x < pos.x - radius) ||
				(current.v1.p.y > pos.y + radius && current.v2.p.y > pos.y + radius) ||
				(current.v1.p.y < pos.y - radius && current.v2.p.y < pos.y - radius) 
			) { continue; }

			// Find the line that is closest based on proximity to end vertices
			double curdist = (current.v1.p - pos.xy + current.v2.p - pos.xy).Length();
			if (!linedef || curdist <= dist)
			{
				linedef = current;
				dist = curdist;
			}
		}

		return linedef;
	}

	void DoLights(TextureID tex, double bottom = -0x7FFFFFFF, double top = 0x7FFFFFFF)
	{
		if (!tex) { return; }
		if (bottom == -0x7FFFFFFF) { bottom = floorz; }
		if (top == 0x7FFFFFFF) { top = ceilingz; }

		if (bottom == top)
		{
			if (bottom > pos.z) { bottom = floorz; }
			else if (top < pos.z) { top = ceilingz; } 
		}

		String texname = TexMan.GetName(tex);

		if (texname.Left(3) ~== "LIT" || texname.Left(3) ~== "LIW")
		{
			int cols, rows, colsize, rowsize;

			if (texname.Mid(4, 1) ~== "W")
			{
				if (texname.Mid(2, 1) ~== "W")
				{
					cols = int(linedef.delta.Length() / 32);
					rows = int((top - bottom) / 16);
					colsize = 32;
					rowsize = 16;
				}
				else
				{
					cols = int(linedef.delta.Length() / 16);
					rows = int((top - bottom) / 32);
					colsize = 16;
					rowsize = 32;
				}
			}
			else
			{
				if (texname.Mid(2, 1) ~== "W")
				{
					cols = int(linedef.delta.Length() / 16);
					rows = int((top - bottom) / 32);
					colsize = 16;
					rowsize = 32;
				}
				else
				{
					cols = int(linedef.delta.Length() / 32);
					rows = int((top - bottom) / 16);
					colsize = 32;
					rowsize = 16;
				}
			}

			Utilities.SpawnLights(self, rows, cols, rowsize, colsize, user_active);
		}
	}
}