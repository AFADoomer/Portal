class Utilities : Actor
{
	static int Round(double input)
	{
		if (input > double(int(input)) + 0.5) { return int(input) + 1; }
		else { return int(input); }
	}

	static void SpawnLights(Actor base, int rows = 1, int cols = 1, int rowsize = 16, int colsize = 16, bool activate = false)
	{
		if (!base) { return; }

		CVar density = Cvar.FindCVar("g_lightdensity");

		double f = 0.5;

		if (density)
		{
			f = clamp(density.GetFloat(), 0.1, 1.0); 
		}

		rows = max(1, round(rows * f));
		cols = max(1, round(cols * f));
		rowsize = round(rowsize / f);
		colsize = round(colsize / f);

		int rowpos = -(rows * rowsize) / 2 + rowsize / 2;
		int colpos = -(cols * colsize) / 2 + colsize / 2;
		int basecolpos = colpos;

		color basecolor = base.fillcolor != -0x9000000 ? base.fillcolor : 0x383840;

		for (int r = 0; r < rows; r++)
		{
			for (int c = 0; c < cols; c++)
			{
				double scale = (LightSpawner(base) && LightSpawner(base).user_maxradius) ? 1.0 : max((4096.0 / f) / (cols * colsize * rows * rowsize), 1.25);
				color clr = (int(basecolor.r * scale) .. " " .. int(basecolor.g * scale) .. " " .. int(basecolor.b * scale));
				color clr2 = (int(basecolor.r * 10.0 / 16.0) .. " " .. int(basecolor.g * 10.0 / 16.0) .. " " .. int(basecolor.b * 10.0 / 16.0));
				int maxradius = int((LightSpawner(base) && LightSpawner(base).user_maxradius) ? LightSpawner(base).user_maxradius : clamp(max(rowsize, colsize) * 4.0, 16.0, 512.0 * f));

				bool sp;
				Actor mo;
				[sp, mo] = base.A_SpawnItemEx("AttenuatedAlphaLight", 1.0, colpos, rowpos, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
				if (sp && mo)
				{
					if (activate) { mo.Activate(null); }

					mo.master = base;
					mo.angle = base.angle;
					mo.pitch = base.pitch;

					double scale = (LightSpawner(base) && LightSpawner(base).user_maxradius) ? 1.0 : max(4096.0 / (cols * colsize * rows * rowsize), 1.25);

					AlphaLight(mo).clr.r = int(basecolor.r * scale);
					AlphaLight(mo).clr.g = int(basecolor.g * scale);
					AlphaLight(mo).clr.b = int(basecolor.b * scale);
					AlphaLight(mo).maxradius = (LightSpawner(base) && LightSpawner(base).user_maxradius) ? LightSpawner(base).user_maxradius : clamp(max(rowsize, colsize) * 4.0 * f, 16.0, 512.0 * f);
					AttenuatedAlphaLight(mo).user_lightlevel = 1.0 / f;

					if (base.tid)
					{
						mo.ChangeTID(base.tid);
					}
				}

				colpos += colsize;
			}

			rowpos += rowsize;
			colpos = basecolpos;
		}
	}

	static Line GetCurrentLine(Actor mo)
	{
		Line linedef;
		double dist;

		BlockLinesIterator it = BlockLinesIterator.Create(mo);

		While (it.Next())
		{
			Line current = it.curline;

			// Discard lines that definitely don't cross the actor's center point
			if (
				(current.v1.p.x > mo.pos.x + mo.radius && current.v2.p.x > mo.pos.x + mo.radius) ||
				(current.v1.p.x < mo.pos.x - mo.radius && current.v2.p.x < mo.pos.x - mo.radius) ||
				(current.v1.p.y > mo.pos.y + mo.radius && current.v2.p.y > mo.pos.y + mo.radius) ||
				(current.v1.p.y < mo.pos.y - mo.radius && current.v2.p.y < mo.pos.y - mo.radius) 
			) { continue; }

			// Find the line that is closest based on proximity to end vertices
			double curdist = (current.v1.p - mo.pos.xy + current.v2.p - mo.pos.xy).Length();
			if (!linedef || curdist <= dist)
			{
				linedef = current;
				dist = curdist;
			}
		}

		return linedef;		
	}

	// Handling for terrain-based pitch/roll calculations...
	static double, double, double SetPitchRoll(Actor mo, bool force = false)
	{
		if (!mo) { return 0; }

		double xoffset = -4;
		double yoffset = -4;

		double testwidth = mo.radius + yoffset;
		double testlength;

		if (!testlength) { testlength = mo.radius + xoffset; }

		// Account for current pitch/roll when measuring corner heights
		testwidth *= abs(cos(mo.roll));
		testlength *= abs(cos(mo.pitch));

		testlength = max(testlength, 1);
		testwidth = max(testwidth, 1);

		double points[4], center, minz = 0x7FFFFFFF, maxz = -0x7FFFFFFF;

		// Get the relative z-height at the four corners of the actor
		double maxstep = mo.MaxStepHeight;
		double maxdrop = mo.MaxDropoffHeight;
/*
int oldpoints[4];
		oldpoints[0] = mo.GetZAt(testlength, testwidth);
		oldpoints[1] = mo.GetZAt(testlength, -testwidth);
		oldpoints[2] = mo.GetZAt(-testlength, testwidth);
		oldpoints[3] = mo.GetZAt(-testlength, -testwidth);
*/
		CarryPointTracer carrytracer;
		carrytracer = new("CarryPointTracer");

		Vector3 tracedir = (0, 0, -1);
		carrytracer.skipactor = mo;

		double zoffset = mo.pos.z + maxstep;
		if (CarryActor(mo)) { zoffset -= CarryActor(mo).zoffset; }
		double dist = 128.0; //maxdrop + maxstep;

		Vector3 tracepos = mo.pos; 
		carrytracer.Trace(tracepos, level.PointInSector(tracepos.xy), tracedir, dist, 0);
		center = carrytracer.Results.HitPos.z;

		tracepos = (mo.pos.xy + RotateVector((testlength, testwidth), mo.angle), zoffset); 
		carrytracer.Trace(tracepos, level.PointInSector(tracepos.xy), tracedir, dist, 0);
		points[1] = carrytracer.Results.HitPos.z;

		tracepos = (mo.pos.xy + RotateVector((testlength, -testwidth), mo.angle), zoffset);
		carrytracer.Trace(tracepos, level.PointInSector(tracepos.xy), tracedir, dist, 0);
		points[0] = carrytracer.Results.HitPos.z;

		tracepos = (mo.pos.xy + RotateVector((-testlength, testwidth), mo.angle), zoffset);
		carrytracer.Trace(tracepos, level.PointInSector(tracepos.xy), tracedir, dist, 0);
		points[3] = carrytracer.Results.HitPos.z;

		tracepos = (mo.pos.xy + RotateVector((-testlength, -testwidth), mo.angle), zoffset);
		carrytracer.Trace(tracepos, level.PointInSector(tracepos.xy), tracedir, dist, 0);
		points[2] = carrytracer.Results.HitPos.z;

		int count;

		for (int i = 0; i < 4; i++)
		{
//			if (points[i] > mo.pos.z + maxstep) { points[i] = 0; } // Ignore the point if you can't climb that high
//			else if (points[i] < mo.pos.z - maxdrop) { points[i] = 0; } // Ignore the point if it's a dropoff
//			else
//			{ 
				points[i] -= mo.floorz;
//			}

			if (points[i] != center) { count++; }
		}

		if (count <= 2 && center == mo.floorz) { return 0; }

		// Use those values to calculate the pitch.roll amounts
		double pitchinput = (points[0] + points[1]) / 2 - (points[2] + points[3]) / 2;
		double rollinput = (points[1] + points[3]) / 2 - (points[0] + points[2]) / 2;

		pitchinput = atan(pitchinput / (testlength * 2));
		rollinput = atan(rollinput / (testwidth * 2));

		// Return the amount that you need to adjust the model z position by in order to keep it looking like it's actually on the ground
		double deltaz = testlength * sin(abs(-pitchinput)) + testwidth * sin(abs(rollinput));

		return deltaz, -pitchinput, rollinput; 
	}

	static void Fizzle(Actor mo)
	{
		if (mo.bSolid)
		{
			Sound DeathSound = mo.DeathSound;
			if (!DeathSound) { DeathSound = "cube/fizzle"; }

			mo.A_StartSound(DeathSound, CHAN_VOICE, 0, 1.0, mo.bBoss ? ATTN_NONE : ATTN_NORM);
		}

		if (mo.master && PortalPlayer(mo.master))
		{
			PortalPlayer(mo.master).DragTarget = null;
			mo.master = null;
		}

		mo.ChangeTID(0); // Clear the TID so a replacement can be spawned if applicable

		mo.bSolid = false;
		mo.bNoInteraction = true;
		mo.bInvulnerable = true;
		mo.bNoTarget = true;
		mo.bMBFBouncer = false;

		mo.alpha = max(mo.alpha - 0.05, 0);
		mo.gravity = 0.1;
		mo.vel = (0, 0, 0.5);
		mo.scale *= 1.01;

		mo.A_SetRenderStyle(mo.alpha, STYLE_TranslucentStencil);

		let spark = mo.A_SpawnProjectile("SingleSpark", FRandom(-mo.Height / 2, mo.Height / 2), FRandom(-mo.Radius, mo.Radius), FRandom(0, 360), CMF_AIMDIRECTION, -90 + FRandom(-45, 45));
		spark.master = mo;

		if (!(mo is "CarryActor") && mo.alpha <= 0) { mo.Destroy(); }
	}

	static bool CheckFizzle(Actor mo, StateLabel fizzlestate = "Death")
	{
		if (!mo.InStateSequence(mo.CurState, mo.FindState(fizzlestate)))
		{
			double heightoffset = 0;

			if (mo is "CarryActor")
			{
				heightoffset = CarryActor(mo).zoffset;
			}

			if (mo.waterlevel)
			{
				F3DFloor w = mo.curSector.Get3dFloor(0);
				if (
					w &&
					w.model.damagetype == "Slime"
				)
				{
					Utilities.DoFizzle(mo, fizzlestate);
					return true;
				}

				TerrainDef t = mo.GetFloorTerrain();
				if (
					t &&
					t.DamageMOD == "Slime"
				)
				{
					Utilities.DoFizzle(mo, fizzlestate);
					return true;
				}
			}

			if (
				mo.pos.z == mo.floorz + heightoffset &&
				mo.floorpic == skyflatnum
			)
			{
				Utilities.DoFizzle(mo, fizzlestate);
				return true;
			}

			Line current = Utilities.GetCurrentLine(mo);
			if (current)
			{
				for (int i = 0; i < 2; i++)
				{
					Side HitSide = current.sidedef[i];

					if (HitSide)
					{
						TextureID tex = HitSide.GetTexture(Side.mid);

						if (tex && TexMan.GetName(tex) ~== "EMANGRIL")
						{
							if (!current.alpha) { return false; }
							else if (HitSide.flags & Side.WALLF_WRAP_MIDTEX || current.flags & Line.ML_WRAP_MIDTEX) { mo.SetStateLabel(fizzlestate); return true; } // If it's floor-to-ceiling, skip checks
							else
							{
								double yoffset = HitSide.GetTextureYOffset(1);
								Vector2 size = TexMan.GetScaledSize(tex);

								if (current.flags & Line.ML_DONTPEGBOTTOM) // Lower unpegged
								{
									if (mo.pos.z > mo.curSector.floorplane.ZAtPoint(mo.pos.xy) + yoffset - 24.0 && mo.pos.z + mo.height < mo.curSector.floorplane.ZAtPoint(mo.pos.xy) + yoffset + size.y + 24.0)
									{
										Utilities.DoFizzle(mo, fizzlestate); return true; 
									}
								}
								else
								{
									if (mo.pos.z > mo.curSector.ceilingplane.ZAtPoint(mo.pos.xy) + yoffset + 24.0 && mo.pos.z + mo.height < mo.curSector.ceilingplane.ZAtPoint(mo.pos.xy) + yoffset - size.y - 24.0)
									{
										Utilities.DoFizzle(mo, fizzlestate); return true; 
									}
								}
							}
						}
					}
				}
			}
		}

		return false;
	}

	static void DoFizzle(Actor mo, StateLabel fizzlestate = "Death")
	{
		if (mo is "CarryActor" && mo.master && mo.master is "PortalPlayer")
		{
			PortalPlayer(mo.master).DropCarried();
		}

		mo.ClearBounce();
		mo.A_StartSound("cube/fizzle", CHAN_AUTO, CHANF_NOSTOP);
		mo.SetStateLabel(fizzlestate);
	}

	static LaserBeam, Actor DrawLaser(Actor origin, LaserBeam beam, Actor hitspot, TraceResults traceresults, Class<Actor> spawnclass = "LaserBeam", Class<Actor> puffclass = "", int damage = 0, double zoffset = 0, bool drawdecal = true, double alpha = 1.0, Class<Actor> hitmarkerclass = "LaserHitMarker")
	{
		if (!traceresults || !origin) { return beam, hitspot; }

		Vector3 beamoffset = origin.pos + (0, 0, zoffset);

		double radiusoffset = traceresults.HitActor ? traceresults.HitActor.radius : 0;

		// Check for hitting water
		if (traceresults.Crossed3DWaterPos.length()) { traceresults.HitPos = traceresults.Crossed3DWaterPos; }
		else if (traceresults.CrossedWaterPos.length()) { traceresults.HitPos = traceresults.CrossedWaterPos; }

		Vector3 hitpos = traceresults.HitPos;

		double dist = ((beamoffset - hitpos) - traceresults.HitVector * radiusoffset).length();

		//Laser beam
		Vector3 beampos = beamoffset + traceresults.HitVector * (dist / 2);
		if (!beam)
		{
			beam = LaserBeam(Spawn(spawnclass, beampos, ALLOW_REPLACE));
			if (beam)
			{
				beam.master = origin;
				beam.target = origin;
			}
		}

		if (beam)
		{
			beam.SetXYZ(beampos);

			beam.pitch = origin.pitch - 90;
			beam.angle = origin.angle;
			beam.scale.x = beam.Default.scale.x * FRandom(0.5, 0.75);
			beam.scale.y = dist * 2.225;
			beam.alpha = beam.Default.alpha * alpha;
		}

		if (hitmarkerclass && !hitspot && damage > 0) { hitspot = Spawn(hitmarkerclass, hitpos - traceresults.HitVector * radiusoffset, ALLOW_REPLACE); }
		if (hitspot)
		{
			hitspot.master = origin;
			hitspot.SetXYZ(hitpos + traceresults.HitVector * radiusoffset);
			hitspot.SetDamage(damage);

			Actor flash = Spawn("Flare", hitspot.pos, ALLOW_REPLACE);
			if (flash)
			{
				flash.scale *= 0.15;
				flash.alpha = max(0.25, 0.6 * alpha);
				flash.A_SetTics(2);
			}
		}

		Actor puff;
		if (hitspot)
		{
			if (traceresults.HitActor)
			{
				Actor m = origin;
				while (m.master && m is "LaserSpot") { m = m.master; }

				traceresults.HitActor.DamageMobj(beam, m, damage, "LaserBeam");

				if (
					!(traceresults.HitActor is "LaserTrigger") && 
					!(traceresults.HitActor is "LaserCube") &&
					!(traceresults.HitActor is "PlatformEndpoint")
				)
				{
					hitspot.A_StartSound("laser/hit", CHAN_6, CHANF_NOSTOP | CHANF_LOOP, 0.25, ATTN_STATIC);

					if (!traceresults.HitActor.bNoBlood && drawdecal)
					{
						puff = Spawn("SmokePuff", hitspot.pos, ALLOW_REPLACE);
						if (puff)
						{
							puff.angle = puff.AngleTo(origin);
						}
					}
				}
				else
				{
					hitspot.A_StopSound(CHAN_6);
				}
			}
			else if (traceresults.HitType == TRACE_HitFloor || traceresults.HitType == TRACE_HitCeiling || traceresults.HitType == TRACE_HitWall)
			{
				// Spawn bullet puff
				if (puffclass != "")
				{
					puff = Spawn(puffclass, hitspot.pos - traceresults.HitVector * 3.0, ALLOW_REPLACE);

					if (puff)
					{
						hitspot.A_StartSound("laser/hit", CHAN_6, CHAN_NOSTOP | CHANF_LOOP, 0.25, ATTN_STATIC);
						if (LaserHitMarker(hitspot) && LaserHitMarker(hitspot).moved)
						{
							puff.angle = origin.AngleTo(puff);
							puff.A_SprayDecal("LaserBeamScorch", 8.0);
						}
						puff.angle = puff.AngleTo(origin);
					}
				}
			}
			else
			{
				hitspot.A_StopSound(CHAN_6);
			}
		}

		return beam, hitspot;
	}

	// Ugh.  Math.  Adapted from https://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
	static double DistanceFromLine(Actor mo, Line l)
	{
		if (!l || !mo) { return 0; }

		Vector2 v1, v2, delta, point;

		v1 = l.v1.p;
		v2 = l.v2.p;
		delta = l.delta;
		point = mo.pos.xy;

		double lengthsquared = (v2 - v1).length() ** 2;

		if (!lengthsquared) { return (v1 - point).length(); }

		double t = clamp((point - v1) dot delta / lengthsquared, 0, 1);
		Vector2 projection = v1 + t * delta;

		return (point - projection).length();
	}

	static double PitchTo(Actor mo, Actor source, double sourcezoffset = 0, double targetzoffset = 0)
	{
		if (!mo || !source) { return 0; }

		double distxy = max(source.Distance2D(mo), 1);
		double distz = (source.pos.z + sourcezoffset) - (mo.pos.z + targetzoffset);

		return -atan(distz / distxy);
	}

	static Actor FindOnMObj(Actor origin, double zoffset = 0.0)
	{
		FLineTraceData onmobjtracer;
		Actor ret = null;
		double retheight = -0x7FFFFFFF;

		// Check center and all four corners, and pick the highest
		origin.LineTrace(0, 1.0, 90, TRF_SOLIDACTORS, -zoffset, 0, 0, onmobjtracer);
		if (onmobjtracer.HitActor && (!onmobjtracer.HitActor.master || onmobjtracer.HitActor.master != origin))
		{
			ret = onmobjtracer.HitActor;
			retheight = onmobjtracer.HitActor.pos.z;
		}

		origin.LineTrace(0, 1.0, 90, TRF_SOLIDACTORS, -zoffset, origin.radius, origin.radius, onmobjtracer);
		if (onmobjtracer.HitActor && (!onmobjtracer.HitActor.master || onmobjtracer.HitActor.master != origin))
		{
			if (onmobjtracer.HitActor.pos.z > retheight)
			{
				ret = onmobjtracer.HitActor;
				retheight = onmobjtracer.HitActor.pos.z;
			}
		}

		origin.LineTrace(0, 1.0, 90, TRF_SOLIDACTORS, -zoffset, origin.radius, -origin.radius, onmobjtracer);
		if (onmobjtracer.HitActor && (!onmobjtracer.HitActor.master || onmobjtracer.HitActor.master != origin))
		{
			if (onmobjtracer.HitActor.pos.z > retheight)
			{
				ret = onmobjtracer.HitActor;
				retheight = onmobjtracer.HitActor.pos.z;
			}
		}

		origin.LineTrace(0, 1.0, 90, TRF_SOLIDACTORS, -zoffset, -origin.radius, -origin.radius, onmobjtracer);
		if (onmobjtracer.HitActor && (!onmobjtracer.HitActor.master || onmobjtracer.HitActor.master != origin))
		{
			if (onmobjtracer.HitActor.pos.z > retheight)
			{
				ret = onmobjtracer.HitActor;
				retheight = onmobjtracer.HitActor.pos.z;
			}
		}

		origin.LineTrace(0, 1.0, 90, TRF_SOLIDACTORS, -zoffset, -origin.radius, origin.radius, onmobjtracer);
		if (onmobjtracer.HitActor && (!onmobjtracer.HitActor.master || onmobjtracer.HitActor.master != origin))
		{
			if (onmobjtracer.HitActor.pos.z > retheight)
			{
				ret = onmobjtracer.HitActor;
				retheight = onmobjtracer.HitActor.pos.z;
			}
		}

		return ret;
	}

	static Vector3 OffsetRelative(Actor origin, double xoffset = 0, double yoffset = 0, double zoffset = 0, double angleoffset = 0, double pitchoffset = 0, double rolloffset = 0)
	{
		if (!origin) { return (xoffset, yoffset, zoffset); }

		Vector2 temp;
		Vector3 offset;

		temp = RotateVector((yoffset, zoffset), origin.roll + rolloffset);
		offset = (xoffset, temp.x, temp.y);

		temp = RotateVector((offset.x, offset.z), -origin.pitch - pitchoffset);
		offset = (temp.x, offset.y, temp.y);

		temp = RotateVector((offset.x, offset.y), origin.angle + angleoffset);
		offset = (temp.x, temp.y, offset.z);

		offset.x *= origin.scale.x;
		offset.y *= origin.scale.x;
		offset.z *= origin.scale.y;

		return offset;
	}

	static String FindFontColor(String c)
	{
		int index;
		
		if (c == "*") { index = msg3color; }
		else if (c == "!") { index = msg4color; }
		else { index = c.ByteAt(0); }

		if (index > 0x5A) { index -= 0x20; }
		index = (index - 0x41) % 26;

		switch (index)
		{
			case 0: return "Brick";
			case 1: return "Tan";
			case 2: return "Gray";
			case 3: return "Green";
			case 4: return "Brown";
			case 5: return "Gold";
			case 6: return "Red";
			case 7: return "Blue";
			case 8: return "Orange";
			case 9: return "White";
			case 10: return "Yellow";
			case 11: return "Untranslated";
			case 12: return "Black";
			case 13: return "Light Blue";
			case 14: return "Cream";
			case 15: return "Olive";
			case 16: return "Dark Green";
			case 17: return "Dark Red";
			case 18: return "Dark Brown";
			case 19: return "Purple";
			case 20: return "Dark Gray";
			case 21: return "Cyan";
			case 22: return "Ice";
			case 23: return "Fire";
			case 24: return "Sapphire";
			case 25: return "Teal";
		}

		return "Untranslated";
	}

	static int HexStringToInt(String input)
	{
		int len = input.length();
		int output = 0;

		input = input.MakeUpper();

		for (int i = 0; i < len; i++)
		{
			int c = input.ByteAt(len - 1 - i);

			if (c >= 0x30 && c <= 0x39) { output += (c - 0x30) * int(0x10 ** i); }
			else if (c >= 0x41 && c <= 0x46) { output += (c - 0x37) * int(0x10 ** i); }
		}

		return output;
	}
}

class FloorOverlayAdjust : Actor
{
	Default
	{
		//$Category Portal/Utilities
		//$Title 3d Floor Overlay
		//$Sprite AMRKA0
		//$Arg0 "Tag of sector to overlay"
	}

	override void BeginPlay()
	{
		if (args[0])
		{
			SectorTagIterator it = level.CreateSectorTagIterator(args[0]);
			int secnum = it.Next();

			if (!secnum) { return; }

			Sector cur = level.Sectors[secnum];
			double dest = cur.CenterFloor() + 0.01;

			if (ceilingz == dest) { return; }

			curSector.MoveCeiling(16, dest, 0, (ceilingz < dest), false);
		}
	}
}

class FlatText : PortalActor
{
	int value;
	Vector3 offset;
	String user_text;
	bool drawn;
	
	Default
	{
		//$Category Portal/Utilities
		//$Title Floating Text
		//$Sprite UNKNA0
		Radius 0;
		Height 0;
		Scale 0.125;
		+NOGRAVITY
		+NOINTERACTION
		+FLATSPRITE
		+BRIGHT
		+NOTONAUTOMAP
		Renderstyle 'AddStencil';
		Alpha 1.0;
		StencilColor "FFFFFF";
		RenderRadius 64;
	}

	States
	{
		Spawn:
			TNT1 A -1;
			Stop;
		Glyphs:
			F033 A 0;
			F034 A 0;
			F035 A 0;
			F036 A 0;
			F037 A 0;
			F038 A 0;
			F039 A 0;
			F040 A 0;
			F041 A 0;
			F042 A 0;
			F043 A 0;
			F044 A 0;
			F045 A 0;
			F046 A 0;
			F047 A 0;
			F048 A 0;
			F049 A 0;
			F050 A 0;
			F051 A 0;
			F052 A 0;
			F053 A 0;
			F054 A 0;
			F055 A 0;
			F056 A 0;
			F057 A 0;
			F058 A 0;
			F059 A 0;
			F060 A 0;
			F061 A 0;
			F062 A 0;
			F063 A 0;
			F064 A 0;
			F065 A 0;
			F066 A 0;
			F067 A 0;
			F068 A 0;
			F069 A 0;
			F070 A 0;
			F071 A 0;
			F072 A 0;
			F073 A 0;
			F074 A 0;
			F075 A 0;
			F076 A 0;
			F077 A 0;
			F078 A 0;
			F079 A 0;
			F080 A 0;
			F081 A 0;
			F082 A 0;
			F083 A 0;
			F084 A 0;
			F085 A 0;
			F086 A 0;
			F087 A 0;
			F088 A 0;
			F089 A 0;
			F090 A 0;
			F091 A 0;
			F092 A 0;
			F093 A 0;
			F094 A 0;
			F095 A 0;
			F096 A 0;
			F097 A 0;
			F098 A 0;
			F099 A 0;
			F100 A 0;
			F101 A 0;
			F102 A 0;
			F103 A 0;
			F104 A 0;
			F105 A 0;
			F106 A 0;
			F107 A 0;
			F108 A 0;
			F109 A 0;
			F110 A 0;
			F111 A 0;
			F112 A 0;
			F113 A 0;
			F114 A 0;
			F115 A 0;
			F116 A 0;
			F117 A 0;
			F118 A 0;
			F119 A 0;
			F120 A 0;
			F121 A 0;
			F122 A 0;
			F123 A 0;
			F124 A 0;
			F125 A 0;
			F126 A 0;
			F127 A 0;
			F128 A 0;
			F129 A 0;
			F130 A 0;
			F131 A 0;
			F132 A 0;
			F133 A 0;
			F134 A 0;
			F135 A 0;
			F136 A 0;
			F137 A 0;
			F138 A 0;
			F139 A 0;
			F140 A 0;
			F141 A 0;
			F142 A 0;
			F143 A 0;
			F144 A 0;
			F145 A 0;
			F146 A 0;
			F147 A 0;
			F148 A 0;
			F149 A 0;
			F150 A 0;
			F151 A 0;
			F152 A 0;
			F153 A 0;
			F154 A 0;
			F155 A 0;
			F156 A 0;
			F157 A 0;
			F158 A 0;
			F159 A 0;
			F160 A 0;
			F161 A 0;
			F162 A 0;
			F163 A 0;
			F164 A 0;
			F165 A 0;
			F166 A 0;
			F167 A 0;
			F168 A 0;
			F169 A 0;
			F170 A 0;
			F171 A 0;
			F172 A 0;
			F173 A 0;
			F174 A 0;
			F175 A 0;
			F176 A 0;
			F177 A 0;
			F178 A 0;
			F179 A 0;
			F180 A 0;
			F181 A 0;
			F182 A 0;
			F183 A 0;
			F184 A 0;
			F185 A 0;
			F186 A 0;
			F187 A 0;
			F188 A 0;
			F189 A 0;
			F190 A 0;
			F191 A 0;
			F192 A 0;
			F193 A 0;
			F194 A 0;
			F195 A 0;
			F196 A 0;
			F197 A 0;
			F198 A 0;
			F199 A 0;
			F200 A 0;
			F201 A 0;
			F202 A 0;
			F203 A 0;
			F204 A 0;
			F205 A 0;
			F206 A 0;
			F207 A 0;
			F208 A 0;
			F209 A 0;
			F210 A 0;
			F211 A 0;
			F212 A 0;
			F213 A 0;
			F214 A 0;
			F215 A 0;
			F216 A 0;
			F217 A 0;
			F218 A 0;
			F219 A 0;
			F220 A 0;
			F221 A 0;
			F222 A 0;
			F223 A 0;
			F224 A 0;
			F225 A 0;
			F226 A 0;
			F227 A 0;
			F228 A 0;
			F229 A 0;
			F230 A 0;
			F231 A 0;
			F232 A 0;
			F233 A 0;
			F234 A 0;
			F235 A 0;
			F236 A 0;
			F237 A 0;
			F238 A 0;
			F239 A 0;
			F240 A 0;
			F241 A 0;
			F242 A 0;
			F243 A 0;
			F244 A 0;
			F245 A 0;
			F246 A 0;
			F247 A 0;
			F248 A 0;
			F249 A 0;
			F250 A 0;
			F251 A 0;
			F252 A 0;
			F253 A 0;
			F254 A 0;
			F255 A 0;
	}

	override void PostBeginPlay()
	{
		if (master)
		{
			SpawnPoint = pos;
			offset = pos - master.pos;
			offset = (RotateVector(offset.xy, -master.angle), offset.z);
		}

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (IsFrozen() || bDormant) { return; }

		if (user_text && !drawn && level.time > 35)
		{
			FlatText.SpawnString(self, user_text, fillcolor);
			drawn = true;
		}

		if (value && value != 32 && level.time % 15 == 0)
		{
			int newsprite = GetSpriteIndex(String.Format("F%03i", value));
			if (newsprite && sprite != newsprite) { sprite = newsprite; }
		}

		Super.Tick();

		if (!master && !user_text) { Destroy(); }

		if (master) { alpha = master.alpha * Default.alpha; }
	}

	static void SpawnString(Actor master, String input, Color clr = 0x000000, double xoffset = 2.0, double yoffset = 0, double zoffset = 0, double scale = 1.0, double rolloffset = 0.0)
	{
		if (!master) { return; }

		int digits = input.Length();

		double width = 16 * 0.125 * scale;
		double height = 33 * 0.125 * scale;

		double linestart = yoffset = yoffset + width / 2;

		color defaultcolor = clr;
		double scalemod = 1.0;

		for (int i = 0; i < digits; i++)
		{
			int code = input.ByteAt(0);

			if (code == 0x5C)
			{
				switch(input.ByteAt(1))
				{
					case 0x43: // \C
					case 0x63: // \c
						String textcolor = "";

						if (input.Mid(2, 1) == "[")
						{
							digits++;
							int place = 2;

							while (++place < input.Length() - 1 && !(input.Mid(place, 1) == "]")) 
							{
								textcolor = textcolor .. input.Mid(place, 1);
								digits--;
							}

							if (input.Mid(place, 1) == "]")
							{
								clr = textcolor;
								digits--;
							}

							input.Remove(0, textcolor.length() + 2);
						}
						else
						{
							textcolor = input.Mid(2, 1);

							if (textcolor == "-")
							{
								clr = defaultcolor;
								scalemod = 1.0;
							}
							else if (textcolor == "+")
							{
								clr = defaultcolor;
								scalemod = 1.15;
							}
							else
							{
								clr = Utilities.FindFontColor(textcolor);
							}

							digits -= 2;
							input.Remove(0, 1);
						}
						break;
					// case 0x47: // \G
					// case 0x67: // \g
					// 	break;
					case 0x50: // \P
					case 0x70: // \p
						String nm = CVar.GetCVar("name", players[consoleplayer]).GetString();
						digits += nm.Length();
						input = input.left(2) .. nm .. input.mid(2);
						break;
					case 0x6E: // \n
					case 0x72: // \r
						zoffset -= height;
						yoffset = linestart;
						break;
					case 0x58:
					case 0x78:
						digits -= 2;
						input = input.left(2) .. String.Format("%c", Utilities.HexStringToInt(input.mid(2, 2))) .. input.mid(4);
						break;
					default:
						Vector3 pos = Utilities.OffsetRelative(master, xoffset, yoffset, zoffset + height * (scalemod - 1.0) / 2, rolloffset:rolloffset);

						Actor mo = Spawn("FlatText", master.pos + pos);
						if (mo)
						{
							FlatText(mo).value = code;
							mo.master = master;
							mo.scale *= master.scale.x * scale * scalemod;
							mo.angle = master.angle;
							mo.pitch = master.pitch - 90;
							mo.roll = master.roll + rolloffset;
							mo.SetShade(clr);
						}

						yoffset += width;

						input.Remove(0, 1);
						break;
				}

				digits--;
				input.Remove(0, 2);
			}
			else
			{
				Vector3 pos = Utilities.OffsetRelative(master, xoffset, yoffset, zoffset + height * (scalemod - 1.0) / 2, rolloffset:rolloffset);

				Actor mo = Spawn("FlatText", master.pos + pos);
				if (mo)
				{
					FlatText(mo).value = code;
					mo.master = master;
					mo.scale *= master.scale.x * scale * scalemod;
					mo.angle = master.angle;
					mo.pitch = master.pitch - 90;
					mo.roll = master.roll + rolloffset;
					mo.SetShade(clr);
				}

				yoffset += width;

				input.Remove(0, 1);
			}
		}
	}
}

class ActorPitchRollInfo
{
	CarryActor mo;
	double zoffset;
	double startpitch;
	double startroll;
	double targetpitch;
	double targetroll;
}

class PitchRollManager : Thinker
{
	Array<ActorPitchRollInfo> Actors;

	static void Add(CarryActor mo)
	{
		if (!mo) { return; }

		ThinkerIterator it = ThinkerIterator.Create("PitchRollManager", Thinker.STAT_Default);
		PitchRollManager manager = PitchRollManager(it.Next());

		if (!manager) { manager = new("PitchRollManager"); }

		if (!manager) { return; }

		manager.AddActor(mo);
	}

	uint FindActor(CarryActor mo)
	{
		for (int i = 0; i < Actors.Size(); i++)
		{
			if (Actors[i] && Actors[i].mo && Actors[i].mo == mo) { return i; }
		}
		return Actors.Size();
	}

	void AddActor(CarryActor mo)
	{
		if (!mo) { return; }

		int i = FindActor(mo);
		if (i == Actors.Size()) // Only add it if it's not already there somehow.
		{
			ActorPitchRollInfo this = New("ActorPitchRollInfo");
			this.mo = mo;
			this.startpitch = mo.pitch;
			this.startroll = mo.roll;
			if (level.time > 15) { [this.zoffset, this.targetpitch, this.targetroll] = Utilities.SetPitchRoll(mo); }
			Actors.Push(this);
		}
		else
		{	
			ActorPitchRollInfo this = actors[i];
			this.startpitch = mo.pitch;
			this.startroll = mo.roll;
			[this.zoffset, this.targetpitch, this.targetroll] = Utilities.SetPitchRoll(mo);
		}
	}

	override void Tick()
	{
		for (int i = 0; i < actors.Size(); i++)
		{
			if (actors[i].mo && actors[i].mo.onground || actors[i].mo.master is "PlayerPawn")
			{
				actors.delete(i);
			}
			else
			{
				// Interpolate to the new values
				if (level.time && level.time < 15)
				{
					actors[i].mo.pitch = actors[i].targetpitch;
					actors[i].mo.roll = actors[i].targetroll;
				}
				else
				{
					let this = actors[i];

					int pstep = 3;
					int rstep = 3;

					int pdir = 0, rdir = 0;
/*
					// It's a cube.  Stop rolling if it's on a flat face...
					if (int(this.mo.pitch) % 90 == int(this.targetpitch)) { this.targetpitch = -this.mo.pitch; }
					if (int(this.mo.roll) % 90 == int(this.targetroll)) { this.targetroll = this.mo.roll; }
*/
					if (this.mo.pitch > this.targetpitch) { this.mo.pitch = max(this.mo.pitch - pstep, this.targetpitch); pdir = -1; }
					else if (this.mo.pitch < this.targetpitch) { this.mo.pitch = min(this.mo.pitch + pstep, this.targetpitch); pdir = 1; }

					if (this.mo.roll > this.targetroll) { this.mo.roll = max(this.mo.roll - rstep, this.targetroll); rdir = 1; }
					else if (this.mo.roll < this.targetroll) { this.mo.roll = min(this.mo.roll + rstep, this.targetroll); rdir = -1; }

					Vector2 move = (sin(this.targetpitch), sin(this.targetroll));
					move = Actor.Rotatevector(move, this.mo.angle);
					this.mo.vel.xy = -move;

					if (this.mo.roll == this.targetroll && this.mo.pitch == this.targetpitch/* || move.length() == 0.0*/) { this.mo.onground = true; }
				}
	
			}
		}
	}
}
