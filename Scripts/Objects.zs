class DoorSprite : PortalActor
{
	Default
	{
		//$Category Portal/Objects/Signs
		//$Title Door
		+WALLSPRITE
		+NOGRAVITY
		+DONTTHRUST
		Radius 0;
		Height 64;
		YScale 1.18;
	}

	States
	{
		Spawn:
			DOOR A -1;
			Stop;
	}
}

class Chair : CarryActor
{
	Default
	{
		Height 17;
		Radius 14;
		Mass 150;
		BounceFactor 0.04;
		BounceSound "chair/bounce";
		WallBounceSound "chair/bounce2";
		Carryactor.SlideSound "chair/slide";
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);
	}

	override void SpawnBlocks()
	{
		A_SpawnItemEx ("Block8x8", -16.0, 0.0, 18.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block8x8", -16.0, 0.0, 26.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class Monitor : PortalActor
{
	int delay;
	String user_text, current;
	
	Default
	{
		//$Category Portal/Decorations
		+SOLID
		+NOGRAVITY
		+DONTTHRUST
		Height 8;
		Radius 4;
		Mass 25;
		PortalActor.GlowOffsetX 4.0;
		PortalActor.GlowColor 0x874644;
		PortalActor.GlowRadius 16.0;
		PortalActor.GlowSpotLight True;
		PortalActor.GlowOuterAngle 160;
	}

	override void Tick()
	{
		Super.Tick();

		if (IsFrozen()) { return; }

		if (bDormant)
		{
			if (frame != 3)
			{
				frame = 3;
				A_RemoveLight("Glow");
			}

			return;
		}

		if (user_text != current || user_variant)
		{
			SetMessage(user_text);

			SetGlow("Glow", glowcolor, glowradius * current.length() / 480, 1.0, glowx, glowy, glowz, glowouterangle, glowpitchoffset);
			frame = (user_variant && !user_text.length()) ? user_variant : 4;
		}

		if (!current.length() && !user_variant)
		{
			if (!delay)
			{
				frame = Random(0, 1);
				SetGlow("Glow", glowcolor, FRandom(glowradius, glowradius + 2), 1.0, glowx, glowy, glowz, glowouterangle, glowpitchoffset);

				delay = 35 * Random(3, 5);
			}

			delay = max(delay - 1, 0);
		}
	}

	void SendMessage(String message, color clr, double textscale, int maxlines, int maxwidth, double xoffset, double yoffset, double zoffset, double rolloffset = 0.0)
	{
		A_RemoveChildren(true, RMVF_EVERYTHING, "FlatText");

		current = message;

		message.Replace("\\n", String.Format("%c", 0x0A));
		message.Replace("\\r", String.Format("%c", 0x0D));

		if (!message.length()) { return; }

		BrokenLines lines = SmallFont.BreakLines(message, maxwidth);
		String text;

		if (lines.Count())
		{
			for (int l = 0; l < min(maxlines, lines.Count()); l++)
			{
				text = text .. lines.StringAt(l) .. "\\n";
			}
		}

		FlatText.SpawnString(self, text, clr, xoffset, yoffset, zoffset, textscale, rolloffset);
	}

	virtual void SetMessage(String message, color clr = 0xFF4203, double textscale = 0.2)
	{
		int maxlines = int(2.666 / textscale);
		int maxwidth = int(80 / textscale);

		SendMessage(message, clr, textscale, maxlines, maxwidth, 5.35, -11.25, 5.5);
	}

	// override void SpawnBlocks()
	// {
	// 	Actor overlay = Spawn("MonitorOverlay", pos + (0, 0, glowz));
	// 	if (overlay)
	// 	{
	// 		overlay.master = self;
	// 		overlay.angle = angle;
	// 		overlay.pitch = pitch;
	// 		overlay.roll = roll;
	// 		overlay.scale = scale;
	// 	}
	// }
}

class MonitorStand : Monitor
{
	Default
	{
		//$Title Monitor (with stand)
		PortalActor.GlowOffsetZ 14.0;
	}
}

class MonitorOverlay : BlockBase
{
	Default
	{
		+NOINTERACTION
		-INVISIBLE
		-SOLID
		RenderStyle "Translucent";
		Alpha 0.99999;
	}

	override void PostBeginPlay()
	{
		Actor.PostBeginPlay();
	}

	override void Tick()
	{
		if (master && !master.bNoInteraction && !bDormant)
		{
			Rotate();
		}

		alpha = clamp(curSector.lightlevel / 256.0, 0.0, 0.999);

		Actor.Tick();
	}
}

class Monitor2 : Monitor
{
	Default
	{
		//$Title Monitor (Large, 64x32)
		Height 1;
		Radius 1;
		XScale 2.2;
		YScale 2.3;
	}

	override void SetMessage(String message, color clr, double textscale)
	{
		int maxlines = int(3.2 / textscale);
		int maxwidth = int(95 / textscale);

		double yoffset = -13.5;
		double zoffset = 6.5;
		double rolloffset = 0.0;

		double modroll = roll % 180;
		if (modroll > 45 && modroll < 153)
		{
			maxlines *= 2;
			maxwidth /= 2;

			yoffset = -6.5;
			zoffset = 13.5;
			rolloffset = 90;
		}

		SendMessage(message, clr, textscale, maxlines, maxwidth, 0.95, yoffset, zoffset, rolloffset);
	}
}

class Desk : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		Height 25;
		Radius 1;
		Mass 150;
	}

	override void SpawnBlocks()
	{
		A_SpawnItemEx("Block24x1", 11.0, -12.0, 24.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("Block24x1", 11.0, 12.0, 24.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 1.0, -22.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 1.0, -22.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 1.0, -22.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 1.0, 22.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 1.0, 22.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 1.0, 22.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 11.0, -22.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 11.0, -22.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 11.0, -22.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 11.0, 22.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 11.0, 22.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 11.0, 22.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 21.0, -22.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 21.0, -22.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 21.0, -22.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 21.0, 22.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 21.0, 22.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 21.0, 22.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class Desk2 : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Desk Corner
		Height 25;
		Radius 1;
		Mass 150;
	}

	override void SpawnBlocks()
	{
		A_SpawnItemEx("Block24x1", 12.0, 2.0, 24.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("Block24x1", -2.0, -12.0, 24.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("Block14x1", -7.0, 7.0, 24.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("Block6x1", 14.0, -14.0, 24.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx("BlockBase", -12.0, 12.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, 12.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, 12.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx("BlockBase", -2.0, 12.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -2.0, 12.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -2.0, 12.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 8.0, 12.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 8.0, 12.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 8.0, 12.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 18.0, 12.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 18.0, 12.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 18.0, 12.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx("BlockBase", -12.0, 2.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, 2.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, 2.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, -8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, -8.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, -8.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, -18.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, -18.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -12.0, -18.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class Desk3 : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Desk (Short Side)
		Height 25;
		Radius 1;
		Mass 150;
	}

	override void SpawnBlocks()
	{
		A_SpawnItemEx("Block24x1", -2.0, 0.0, 24.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -10.0, 8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -10.0, 8.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -10.0, 8.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -2.0, 8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -2.0, 8.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", -2.0, 8.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 6.0, 8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 6.0, 8.0, 8.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx("BlockBase", 6.0, 8.0, 16.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class PortalSpawner : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Generic Emitter
		+NOGRAVITY
		+NOINTERACTION
		+DONTTHRUST
		Height 0;
		Radius 4;
		Mass 50;
	}

	override void PostBeginPlay()
	{
//		A_AttachLight("FizzlerIndicatorR", DynamicLight.PulseLight, 0x00000000, 12, 14, DYNAMICLIGHT.LF_ATTENUATE, (0, 1, 0), 6);
//		A_AttachLight("FizzlerIndicatorL", DynamicLight.PulseLight, 0x00000000, 12, 14, DYNAMICLIGHT.LF_ATTENUATE, (0, -1, 0), 6);

		A_AttachLight("FizzlerIndicatorR1", DynamicLight.PulseLight, 0x00000000, 4, 6, DYNAMICLIGHT.LF_ATTENUATE, (0, 1, 12), 6);
		A_AttachLight("FizzlerIndicatorR2", DynamicLight.PulseLight, 0x00000000, 4, 6, DYNAMICLIGHT.LF_ATTENUATE, (3, 1, 0), 6);
		A_AttachLight("FizzlerIndicatorR3", DynamicLight.PulseLight, 0x00000000, 4, 6, DYNAMICLIGHT.LF_ATTENUATE, (0, 1, -12), 6);
		A_AttachLight("FizzlerIndicatorL1", DynamicLight.PulseLight, 0x00000000, 4, 6, DYNAMICLIGHT.LF_ATTENUATE, (0, -1, 12), 6);
		A_AttachLight("FizzlerIndicatorL2", DynamicLight.PulseLight, 0x00000000, 4, 6, DYNAMICLIGHT.LF_ATTENUATE, (3, -1, 0), 6);
		A_AttachLight("FizzlerIndicatorL3", DynamicLight.PulseLight, 0x00000000, 4, 6, DYNAMICLIGHT.LF_ATTENUATE, (0, -1, -12), 6);

		Super.PostBeginPlay();
	}
}

class PitDetails : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Pit Details
		+NOGRAVITY
		+DONTTHRUST
		Height 8;
		Radius 1;
		RenderRadius 64.0;
		Species "Block";
	}
}

class PitDetails2 : PitDetails
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Pit Details (Alternate)
	}
}

class Pipe : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		+NOGRAVITY
		+DONTTHRUST
		Height 1;
		Radius 24;
		Mass 25;
		Species "Block";
	}
}

class PipeBend : Pipe
{
	Default
	{
		//$Title Pipe Bend (90 degrees, triple)
	}
}

class PipeBendSingle : Pipe
{
	Default
	{
		//$Title Pipe Bend (90 degrees, single)
	}
}

class PipeBendOffset : Pipe
{
	Default
	{
		//$Title Pipe Bend (Offset)
	}
}

class SignBase : Actor
{
	Default
	{
		//$Category Portal/Objects/Signs
		+FLATSPRITE
		+NOGRAVITY
		+NOBLOCKMAP
		+DONTTHRUST
		Radius 0;
		Height 0;
		RenderRadius 128.0;
	}

	States
	{
		Spawn:
			SIGN A -1;
			Stop;
	}
}

class SignExit : SignBase
{
	Default
	{
		//$Title Sign - Exit
	}
}

class SignCubeDrop : SignBase
{
	Default
	{
		//$Title Sign - Cube Drop
	}

	States
	{
		Spawn:
			SIGN B -1;
			Stop;
	}
}

class SignOverhead : SignBase
{
	Default
	{
		//$Title Sign - Hazard (Cube Overhead)
	}

	States
	{
		Spawn:
			SIGN C -1;
			Stop;
	}
}

class SignArrowD : SignBase
{
	Default
	{
		//$Title Sign - Arrow Down
	}

	States
	{
		Spawn:
			SIGN D -1;
			Stop;
	}
}

class SignArrowU : SignBase
{
	Default
	{
		//$Title Sign - Arrow Up
	}

	States
	{
		Spawn:
			SIGN E -1;
			Stop;
	}
}

class SignArrowL : SignBase
{
	Default
	{
		//$Title Sign - Arrow Left
	}

	States
	{
		Spawn:
			SIGN F -1;
			Stop;
	}
}

class SignArrowR : SignBase
{
	Default
	{
		//$Title Sign - Arrow Right
	}

	States
	{
		Spawn:
			SIGN G -1;
			Stop;
	}
}

class SignDrown : SignBase
{
	Default
	{
		//$Title Sign - Hazard (Drown)
	}

	States
	{
		Spawn:
			SIGN H -1;
			Stop;
	}
}

class SignFling: SignBase
{
	Default
	{
		//$Title Sign - Fling (Enter)
	}

	States
	{
		Spawn:
			SIGN I -1;
			Stop;
	}
}

class SignFling2 : SignBase
{
	Default
	{
		//$Title Sign - Fling (Exit)
	}

	States
	{
		Spawn:
			SIGN J -1;
			Stop;
	}
}

class SignPellet : SignBase
{
	Default
	{
		//$Title Sign - Hazard (Pellet)
	}

	States
	{
		Spawn:
			SIGN K -1;
			Stop;
	}
}

class SignPelletTarget : SignBase
{
	Default
	{
		//$Title Sign - Pellet Target
	}

	States
	{
		Spawn:
			SIGN L -1;
			Stop;
	}
}

class SignPoison : SignBase
{
	Default
	{
		//$Title Sign - Hazard (Poison)
	}

	States
	{
		Spawn:
			SIGN M -1;
			Stop;
	}
}

class SignTurrets : SignBase
{
	Default
	{
		//$Title Sign - Hazard (Turrets)
	}

	States
	{
		Spawn:
			SIGN N -1;
			Stop;
	}
}

class SignCake : SignBase
{
	Default
	{
		//$Title Sign - Cake
	}

	States
	{
		Spawn:
			SIGN O -1;
			Stop;
	}
}

class SignStatus : SignBase
{
	Default
	{
		//$Title Sign - Door Status
	}

	States
	{
		Spawn:
		Inactive:
			SIGN X 1;
			Loop;
		Active:
			SIGN V 1;
			Loop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER + 1);
	}
}

class Dot1 : SignBase
{
	Default
	{
		-SOLID
		+NOINTERACTION
	}

	States
	{
		Spawn:
			DOTG A 1;
		Inactive:
			DOTG # 1;
			Loop;
		Active:
			DOTO # 1;
			Loop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER + 1);
	}
}

class Dot2 : Dot1 { States { Spawn: DOTG B 1; Goto Inactive; } }
class Dot4 : Dot1 { States { Spawn: DOTG C 1; Goto Inactive; } }
class Dot8 : Dot1 { States { Spawn: DOTG D 1; Goto Inactive; } }
class Dot16 : Dot1 { States { Spawn: DOTG E 1; Goto Inactive; } }
class Dot32 : Dot1 { States { Spawn: DOTG F 1; Goto Inactive; } }

class UACLogo : SignBase
{
	Default
	{
		//$Title UAC Logo
	}

	States { Spawn: SIGN Y -1; Stop; }
}

class UACLogoW : SignBase
{ 
	Default
	{
		//$Title UAC Logo (White)
	}

	States { Spawn: SIGN Z -1; Stop; }
}

class UAC : SignBase
{
	Default
	{
		//$Title UAC Logo (Graphic only)
	}

	States { Spawn: SIGN [ -1; Stop; }
}

class UACW : SignBase
{
	Default
	{
		//$Title UAC Logo (White, Graphic only)
	}

	States { Spawn: SIGN ] -1; Stop; }
}

class SignTag1 : SignBase
{
	Default
	{
		//$Title Sign - Tag 1
	}

	States { Spawn: STAG A -1; Stop; }
}

class SignTag2 : SignBase
{
	Default
	{
		//$Title Sign - Tag 2
	}

	States { Spawn: STAG B -1; Stop; }
}

class SignTag3 : SignBase
{
	Default
	{
		//$Title Sign - Tag 3
	}

	States { Spawn: STAG C -1; Stop; }
}

class SignTag4 : SignBase
{
	Default
	{
		//$Title Sign - Tag 4
	}

	States { Spawn: STAG D -1; Stop; }
}

class SignCrusher : SignBase
{
	Default
	{
		//$Title Sign - Hazard (Crusher)
	}

	States { Spawn: SIGO A -1; Stop; }
}


class SignCatapult : SignBase
{
	Default
	{
		//$Title Sign - Catapult
	}

	States { Spawn: SIGO B -1; Stop; }
}

class Grid : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		+SOLID
		+NOGRAVITY
		+DONTTHRUST
		Height 1;
		Radius 40;
		Species "Block";
	}
}

class GridComplete : Grid
{
	Default
	{
		//$Title Grid (Complete edge)
	}
}

class Grid1x3 : Grid
{
	Default
	{
		//$Title Grid (Complete edge, 1x3)
		Radius 14;
	}
}

class Skybox : PortalActor
{
	Default
	{
		//$Category Portal/Skyboxes
		//$Title Skybox Sphere (Blue)
		+NOGRAVITY
		Height 32;
		Radius 32;
	}
}

class SkyboxSky : PortalActor
{
	Default
	{
		//$Category Portal/Skyboxes
		//$Title Skybox Sphere (Sky)
		+NOGRAVITY
		Height 32;
		Radius 32;
	}
}

class Launcher : PortalActor
{
	double dist;

	Default
	{
		//$Category Portal/Objects
		+SPECIAL
		+FLATSPRITE
		Height 1;
		Radius 16;
		Speed 12.0;
		Scale 1.8;
	}

	States
	{
		Spawn:
			UNKN A 5 CheckActivators();
			Loop;
	}

	override void PostBeginPlay()
	{
		FindTarget();
		A_Face(target);

		Super.PostBeginPlay();
	}

	override void Touch(Actor toucher)
	{
		if (!toucher.bShootable || !toucher.bSolid || (toucher.master && toucher.master is "PlayerPawn")) { return; }

		Speed = max(Default.Speed * dist / 512.0, Default.Speed);

		// Calculate trajectory here
		bool success;
		Vector3 trajectory;
		double g;

		Vector2 midpoint = pos.xy + ((target.pos.x - toucher.pos.x) / 2, (target.pos.y - toucher.pos.y) / 2);

		double h = GetZAt(midpoint.x, midpoint.y, 0, GZF_ABSOLUTEPOS | GZF_CEILING) - toucher.height - 16.0;
		double h1 = GetZAt(toucher.pos.x, toucher.pos.y, 0, GZF_ABSOLUTEPOS | GZF_CEILING) - toucher.height - 16.0;
		double h2 = GetZAt(target.pos.x, target.pos.y, 0, GZF_ABSOLUTEPOS | GZF_CEILING) - toucher.height - 16.0;

		h = min(h, min(h1, h2));

		if (h - pos.z < 0) { h = max(0, target.pos.z - pos.z); } // Fudge if wierdness happens (launchers on 3d floors can be weird)

		[success, trajectory, g] = GetArc(toucher.pos, Speed, target.pos, h);

		if (success)
		{
			A_StartSound("spring/launch", CHAN_AUTO, 0, 1.0);
			if (!toucher.player) { toucher.master = self; }
			toucher.vel = (trajectory.xy * (toucher.player ? 1.25 : 1.0), trajectory.z);
			toucher.gravity = g;
		}
	}

	void CheckActivators()
	{
		BlockThingsIterator it = BlockThingsIterator.Create(self, Radius);
		Actor mo;

		while (it.Next() && (mo = it.thing))
		{
			if (Distance3D(mo) - mo.radius <= Radius && mo.bSolid && !mo.bNoInteraction && (mo.bPushable || mo is "CarryActor" || mo.player)) { Touch(mo); }
		}
	}

	void FindTarget()
	{
		ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_USER + 2);
		Actor mo;

		while (mo = Actor(it.Next(false)))
		{
			if (mo.tid == tid)
			{
				target = mo;
				dist = Distance2D(mo); 
				return;
			}
		}
	}

	// Modified from https://github.com/forrestthewoods/lib_fts/blob/master/code/fts_ballistic_trajectory.cs
	bool, Vector3, double GetArc(Vector3 proj_pos, double lateral_speed, Vector3 target_pos, double max_height)
	{
		Vector3 fire_velocity = (0, 0, 0);
		double gravity = 0.0;

		if (developer && (proj_pos == target_pos || lateral_speed <= 0 || max_height < proj_pos.z))
		{
			console.printf("\cgERROR: \clPassed invalid data to ballistic arc calculation!");
			return false, (0, 0, 0), 0.0;
		}

		Vector3 diff = target_pos - proj_pos;
		double lateralDist = diff.xy.length();

		double time;
		if (!lateralDist) { time = diff.z / lateral_Speed; }
		else { time = lateralDist / lateral_speed; }

		if (!time) { time = 35.0; }

		fire_velocity.xy = diff.xy.Unit() * lateral_speed;

		// System of equations. Hit max_height at t=.5*time. Hit target at t=time.
		//
		// peak = y0 + vertical_speed*halfTime + .5*gravity*halfTime^2
		// end = y0 + vertical_speed*time + .5*gravity*time^s
		// Wolfram Alpha: solve b = a + .5*v*t + .5*g*(.5*t)^2, c = a + vt + .5*g*t^2 for g, v
		double a = proj_pos.z;       // initial
		double b = max_height;       // peak
		double c = target_pos.z;     // final

		gravity = -4 * (a - 2 * b + c) / (time * time);
		fire_velocity.z = -(3 * a - 4 * b + c) / time;

		return true, fire_velocity, gravity;
	}
}

class LightFixture : PortalActor
{
	Class<Actor> paneclass;
	Actor panes;
	double user_lightlevel, user_flicker, user_radius;

	Property PaneClass:paneclass;
	Property LightLevel:user_lightlevel;

	Default
	{
		//$Category Portal/Lights
		//$Title Light Fixture (Standard)
		+NOGRAVITY
		+NOINTERACTION
		Height 2;
		StencilColor "a8a8c0";
		PortalActor.GlowOffsetZ -4.0;
		PortalActor.GlowPitchOffset -90.0;
		LightFixture.PaneClass "LightFixturePanes";
		LightFixture.LightLevel 1.5;
	}

	override void PostBeginPlay()
	{
		glowradius = user_radius ? user_radius : (pos.z - floorz);
		glowcolor = fillcolor;

		InitializeLight();

		panes = Spawn(paneclass, pos);
		if (panes)
		{
			panes.master = self;
			panes.roll = roll;
			panes.pitch = pitch;
			panes.angle = angle;
			panes.scale = scale;
			panes.SetShade(fillcolor);
		}

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (IsFrozen())
		{
			if (glowflickertime) { glowflickertime++; }
			return;
		}

		if (!bDormant)
		{
			if (glowflickertime)
			{
				if (level.time < glowflickertime)
				{
					glowradius = (glowflickertime - level.time > 35) ? 0 : Random(maxglowradius / 4, maxglowradius);
				}
				else
				{
					glowradius = maxglowradius;
					glowflickertime = 0;
				}
			}

			glowcolor = fillcolor;
			double intensity = user_lightlevel;

			if (glowflickertime == level.time + 15)
			{
				A_StartSound("lights/flicker", CHAN_AUTO, CHANF_NOSTOP, FRandom(0.0625, 0.125), ATTN_NORM, FRandom(0.8, 1.2));
			}

			if (user_flicker && (level.time % Random(1, int(max(1, 35 - user_flicker))) == 0))
			{
				intensity = FRandom(0, user_lightlevel * 1.25);
			}

			SetGlow("Glow", glowcolor, glowradius, intensity, glowx, glowy, glowz, glowouterangle, glowpitchoffset);

			if (panes)
			{
				let c = fillcolor;

				int r = int(max(c.r * alpha * 0.85 * intensity, 8));
				int g = int(max(c.g * alpha * 0.85 * intensity, 8));
				int b = int(max(c.b * alpha * 0.85 * intensity, 8));

				c = color(r, g, b);

				if (glowradius < maxglowradius) { panes.alpha = panes.Default.alpha * glowradius / maxglowradius; }

				panes.SetShade(C);
			}
		}
		else
		{
			A_RemoveLight("Glow");
		}

		Actor.Tick();
	}

	override void OnDestroy()
	{
		A_RemoveLight("Glow");
		if (panes) { panes.Destroy(); }
	}

	virtual void InitializeLight()
	{
		if (SpawnFlags & MTF_DORMANT) { Deactivate(null); }
		else { Activate(null); }
	}

	override void Activate(Actor activator)
	{
		Super.Activate(activator);

		if (panes) { panes.Activate(activator); }
	}

	override void Deactivate(Actor activator)
	{
		Super.Deactivate(activator);

		if (panes) { panes.Deactivate(activator); }
	}
}

class LightFixtureObservation : LightFixture
{
	Default
	{
		//$Title Light Fixture (Observation Area)
		LightFixture.LightLevel 2.0;
	}

	override void Tick()
	{
		Super.Tick();

		If (IsFrozen()) { return; }

		if (!bDormant)
		{
			SetGlow("ChamberLighting", fillcolor, 384.0, alpha * user_lightlevel * 2.5, glowx, glowy, glowz + 48.0, glowouterangle, glowpitchoffset - 90);
		}
		else
		{
			A_RemoveLight("ChamberLighting");
		}
	}

	override void OnDestroy()
	{
		A_RemoveLight("ChamberLighting");

		Super.OnDestroy();
	}
}

class LightFixturePanes : PortalActor
{
	Actor bulb;
	Class<Actor> bulbclass;

	Property BulbClass:bulbclass;

	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+BRIGHT
		Renderstyle "AddStencil";
		LightFixturePanes.BulbClass "LightFixtureBulb";
	}

	override void PostBeginPlay()
	{
		if (bulbclass)
		{
			bulb = Spawn(bulbclass, pos);
			if (bulb)
			{
				bulb.master = self;
				bulb.roll = roll;
				bulb.pitch = pitch;
				bulb.angle = angle;
				bulb.scale = scale;
			}
		}

		Super.PostBeginPlay();
	}

	override void OnDestroy()
	{
		if (bulb) { bulb.Destroy(); }
	}

	override void Tick()
	{
		if (master)
		{
			bBright = (master.alpha > 0 && !master.bStandStill && (!LightFixture(master) || !LightFixture(master).bDormant));
			bDormant = master.bDormant;
		}

		Super.Tick();
	}
}

class LightFixtureBulb : PortalActor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		Alpha 1.0;
	}

	override void Tick()
	{
		if (master)
		{
			let c = master.fillcolor;

			int r = max(c.r, 8);
			int g = max(c.g, 8);
			int b = max(c.b, 8);

			c = color(r, g, b);

			SetShade(c);
		}

		Super.Tick();
	}
}

class Silhouette : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Silhouette
		-SOLID
		Speed 1;
		Scale 0.5;
		Renderstyle "Stencil";
		StencilColor "000000";
		Alpha 0.3;
		DropItem "";
	}

	States
	{
		Spawn:
			SCN2 AAAAAABBBBBBCCCCCCDDDDDD 1 A_Wander;
			Loop;
	}

	override void Tick()
	{
		double dist = Distance2D(players[consoleplayer].mo);

		if (dist < 768)
		{
			alpha = clamp((dist - 128) / 768, 0, 1.0) * Default.alpha;
		}
		else
		{
			alpha = Default.alpha;
		}

		Super.Tick();
	}
}

class Tank : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		+NOGRAVITY
		+DONTTHRUST
		Radius 64;
		Height 1;
	}
}

class Ladder : LadderBase
{
	Default
	{
		//$Category Portal/Ladders
	}
}

class LadderExtension : Ladder
{
	Default
	{
		//$Title Ladder Extension
	}
}

class LadderRung : Ladder
{
	Default
	{
		//$Title Ladder Rung
		Height 4;
		Radius 16;
	}
}

class TowerSegment : Ladder
{
	Default
	{
		//$Title Tower Segment (climbable)
		+SOLID
		-NOINTERACTION
		Height 42;
		Radius 12;
		LadderBase.ClimbRadius 24;
		LadderBase.Friction 0.5; // Slow to climb these
	}
}

class Tower : PortalActor
{
	Default
	{
		//$Title Tower (256-high, non-climbable)
		+NOGRAVITY
		+SOLID
		Height 256;
		Radius 16;
	}
}

class DebrisWall : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Wall Debris (X - Clean)
		+FLATSPRITE
		+NOGRAVITY
		+DONTTHRUST
		Radius 0;
		Height 0;
		RenderRadius 128.0;
	}
}

class DebrisWall2 : DebrisWall
{
	Default
	{
		//$Title Wall Debris (4 holes - Rust)
	}
}

class DebrisWall3 : DebrisWall
{
	Default
	{
		//$Title Wall Debris (X - Rust)
	}
}

class DebrisWall4 : DebrisWall
{
	Default
	{
		//$Title Wall Debris (1 hole - Clean)
	}
}

class DebrisWall5 : DebrisWall
{
	Default
	{
		//$Title Wall Debris (4 holes - Clean)
	}
}

class DebrisWall6 : DebrisWall
{
	Default
	{
		//$Title Wall Debris (X - Rust with grate)
	}
}

class DebrisWall7 : DebrisWall
{
	Default
	{
		//$Title Wall Debris (1 hole - Rust)
	}
}

class Cone : CarryActor
{
	Default
	{
		Height 18;
		Radius 6;
		Mass 100;
		BounceFactor 0.02;
		BounceSound "cone/bounce";
		WallBounceSound "cone/bounce2";
		Carryactor.SlideSound "cone/slide";
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);
	}
}

class OilBarrel : CarryActor
{
	Default
	{
		//$Title Oil Drum
		+DONTTHRUST
		-NODAMAGE
		Height 33;
		Radius 12;
		Mass 1500;
		Health 150;
		BounceFactor 0.001;
		BounceSound "barrel/bounce";
		WallBounceSound "barrel/bounce";
		Carryactor.SlideSound "barrel/slide";
		PortalActor.StepSound "footsteps/grate";
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (user_variant == 4)
		{
			explode = true;
		}
	}
}

class Crate : Cube
{
	Default
	{
		//$Category Portal/Decorations
		+SOLID
		+CANPASS
		Height 50;
		Radius 32;
		Scale 1.0;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (scale.x > 0.5 || scale.y > 0.5) { bPushable = false; }
	}
}

class IndustrialLight : LightFixture
{
	Default
	{
		//$Title Industrial Light
		LightFixture.PaneClass "IndustrialLightPanes";
		PortalActor.GlowOuterAngle 160;
	}
}

class IndustrialLightPanes : LightFixturePanes
{
	Default
	{
		LightFixturePanes.BulbClass "IndustrialLightBulb";
	}
}

class IndustrialLightBulb : LightFixtureBulb
{
	Default
	{
		RenderStyle "AddStencil";
		Alpha 0.95;
	}
}

class OfficeLight : LightFixture
{
	Default
	{
		//$Title Office Light
		LightFixture.PaneClass "OfficeLightPanes";
		PortalActor.GlowOuterAngle 120;
	}
}

class OfficeLightPanes : LightFixturePanes
{
	Default
	{
		LightFixturePanes.BulbClass "OfficeLightBulb";
	}
}

class OfficeLightBulb : LightFixtureBulb {}

class BTSLight : OfficeLight
{
	Actor shield;

	Default
	{
		//$Title Behind the Scenes Light
		LightFixture.PaneClass "BTSLightPanes";
		PortalActor.GlowOuterAngle 160;
		PortalActor.GlowPitchOffset 0.0;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		
		shield = Spawn("BTSLightShield", pos);
		if (shield)
		{
			shield.angle = angle;
			shield.pitch = pitch;
			shield.roll = roll;
		}
	}

	override void OnDestroy()
	{
		Super.OnDestroy();

		if (shield) { shield.Destroy(); }
	}
}

class BTSLightPanes : OfficeLightPanes
{
	Default
	{
		LightFixturePanes.BulbClass "BTSLightBulb";
	}
}

class BTSLightBulb : OfficeLightBulb {}

class BTSLightShield : PortalActor
{
	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		RenderStyle "Translucent";
		Alpha 0.99999;
	}
}

class DownLight : LightFixture
{
	Default
	{
		//$Title Angled Light (Downlight)
		LightFixture.PaneClass "DownLightPanes";
		PortalActor.GlowOuterAngle 90;
	}
}

class DownLightPanes : LightFixturePanes
{
	Default
	{
		LightFixturePanes.BulbClass "DownLightBulb";
	}
}

class DownLightBulb : LightFixtureBulb
{
	Default
	{
		RenderStyle "AddStencil";
	}
}

class Stairway : PortalActor // Base class, not spawned directly
{
	int size;

	Property Size:size;

	Default
	{
		//$Category Portal/Decorations
		+NOGRAVITY
		-SOLID
		+SHOOTABLE
		+NOBLOOD
		+INVULNERABLE
		+NODAMAGE
		+DONTTHRUST
		+NOTAUTOAIMED
		Height 16;
		Radius 1;
		RenderRadius 256.0;
		Stairway.Size 96;
		PortalActor.StepSound "footsteps/grate";
	}

	override void SpawnBlocks()
	{
		// Thing-based steps
		double y = 12.0;
		double z = 0.0;
		for (double x = -8.0; z > -size; x -= 13.333)
		{
			A_SpawnItemEx ("Step", x, y, z, 0, 0, 0, 0, SXF_SETMASTER);
			A_SpawnItemEx ("Step", x, -y, z, 0, 0, 0, 0, SXF_SETMASTER);

			z -= 10.0;
		}

		if (size > 32)
		{
			// Thing-based railings
			A_SpawnItemEx ("RailBlock", 0.0, 26.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
			A_SpawnItemEx ("RailBlock", 0.0, -26.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

			double stepx = -16.0;
			double stepz;
			for (stepz = 12.0; stepz > -size * 0.7; stepz -= 12.0)
			{
				A_SpawnItemEx ("RailBlock", stepx, 26.0, stepz, 0, 0, 0, 0, SXF_SETMASTER);
				A_SpawnItemEx ("RailBlock", stepx, -26.0, stepz, 0, 0, 0, 0, SXF_SETMASTER);

				stepx -= 16.0;
			}
		}
	}
}

class Stairway32 : Stairway
{
	Default
	{
		//$Title Stairway (32 high)
		Stairway.Size 32;
	}
}

class Stairway64 : Stairway
{
	Default
	{
		//$Title Stairway (64-high)
		Stairway.Size 64;
	}
}

class Stairway96 : Stairway
{
	Default
	{
		//$Title Stairway (96-high)
		Stairway.Size 96;
	}
}

class Stairway128 : Stairway
{
	Default
	{
		//$Title Stairway (128-high)
		Stairway.Size 128;
	}
}

class Rail : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Rail (Long)
		+NOGRAVITY
		-SOLID
		+SHOOTABLE
		+NOBLOOD
		+INVULNERABLE
		+NODAMAGE
		+DONTTHRUST
		+NOTAUTOAIMED
		Height 16;
		Radius 1;
		RenderRadius 256.0;
		PortalActor.StepSound "footsteps/grate";
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", 0.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 20.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 40.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 60.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 80.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 100.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class RailMedium : Rail
{
	Default
	{
		//$Title Rail (Medium)
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", 0.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 20.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 40.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 60.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 70.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class RailShort : Rail
{
	Default
	{
		//$Title Rail (Short)
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", 0.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 20.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class RailStub : Rail
{
	Default
	{
		//$Title Rail (Stub)
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", 0.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 10.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class RailPost : Rail
{
	Default
	{
		//$Title Rail (Post)
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", 0.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class Tile2x2 : CarryActor
{
	bool moved;

	Default
	{
//		-SOLID;
		Height 32;
		Radius 16;
		Mass 200;
		RenderRadius 128;
		BounceSound "chair/bounce";
		WallBounceSound "chair/bounce";
		CarryActor.SlideSound "chair/slide";
	}

	States
	{
		Spawn:
			UNKN # -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		pushfactor = 0.0;

		bDormant = (SpawnFlags & MTF_DORMANT);

		if (bDormant)
		{
			Fall();
			bDormant = false;
		}
	}

	override void Tick()
	{
		if (
			GetAge() > 15 && 
			!moved && 
			vel.length() > 1.0 && 
			!(master && master is "PlayerPawn") &&
			pos.z <= floorz + zoffset
		)
		{
			Fall();
		}

		Super.Tick();
	}

	void Fall()
	{
		frame = 1;
		centermodel = false;
		spawnheight = 8;
		if (block) { block.Destroy(); }
	
		if (!bDormant)
		{
			bSolid = true;
			bNoInteraction = false;
			A_ChangeLinkFlags(0);
			moved = true;
			pitch = 0;
			pushfactor = 100.0 / mass;
		}
	}

	override void Activate(actor activator)
	{
		tics = Random(1, 70);

		A_SetSize(Default.Radius / 2);

		vel.x = FRandom(-0.5, 0.5);
		vel.y = FRandom(-0.5, 0.5);

		bDormant = false;
		bNoInteraction = false;
		A_ChangeLinkFlags(0);
		bNoGravity = false;

		Super.Activate(activator);
	}
}

class Tile4x4 : Tile2x2
{
	Default
	{
		Height 16;
		Radius 8;
		Mass 50;
	}
}

class Tile2x2W : Tile2x2 {}

class Crusher : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Crusher Platform Top (Round)
		+NOINTERACTION
		+MOVEWITHSECTOR
		Height 0;
		Radius 32;
	}
}

class BigPipe : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Industrial Pipe
		+NOGRAVITY
		+NOINTERACTION
		Height 0;
		Radius 0;
		RenderRadius 256.0;
	}

	override void SpawnBlocks()
	{
		FLineTraceData trace;
		double dist = 235.0 * scale.x;

		LineTrace(angle, dist, pitch, TRF_THRUACTORS | TRF_THRUBLOCK | TRF_THRUHITSCAN, 0, 1.0, 0, trace);

		if (trace.Distance)
		{
			dist = min(dist, trace.Distance);

			Vector3 step = (42.0 * scale.x) * trace.HitDir;

			Vector3 newpos = pos + (0, 0, -21.0 * scale.y) + (step / 2);

			for (double x = 22.0 * scale.x; x < dist; x += 42.0 * scale.x)
			{
				Actor mo = Spawn("Block42x42", newpos);
				mo.master = self;
				mo.bDormant = true;

				newpos += step;
			}

			// Make sure the end is covered
			newpos = pos + (0, 0, -21.0 * scale.y) + trace.HitDir * (trace.Distance - 21.0 * scale.x);
			Actor mo = Spawn("Block42x42", newpos);
			mo.master = self;
			mo.bDormant = true;
		}
	}
}

class BigPipeBend : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Industrial Pipe (90 Degree Bend)
		+NOGRAVITY
		Height 0;
		Radius 0;
		RenderRadius 64.0;
	}

	override void SpawnBlocks()
	{
		Actor mo;

		mo = Spawn("Block42x42");
		if (mo)
		{
			mo.master = self;
			OffsetRelative(mo, -21.0, 0, -21.0);
		}

		mo = Spawn("Block42x42");
		if (mo)
		{
			mo.master = self;
			OffsetRelative(mo, -38.0, 0, -42.0);
		}
	}
}

class BigPipeJoint : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Industrial Pipe (Joint)
		+NOGRAVITY
		+NOINTERACTION
		Height 0;
		Radius 0;
		RenderRadius 256.0;
	}
}

class SkyboxGrid : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Skybox Grid (with uprights)
		+NOINTERACTION
		Height 0;
		Radius 0;
		RenderRadius 256.0;
	}
}

class SkyboxGridLarge : SkyboxGrid
{
	Default
	{
		//$Title Skybox Grid (Full-sized, with uprights)
		RenderRadius 2048.0;
	}
}

class SkyboxGrid2 : SkyboxGrid
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Skybox Grid
	}
}

class SkyboxGrid2Large : SkyboxGrid
{
	Default
	{
		//$Title Skybox Grid (Full-sized)
		RenderRadius 2048.0;
	}
}

class GirderGrid : SkyboxGrid
{
	Default
	{
		//$Title Girder Grid
		+NOGRAVITY
		RenderRadius 2048.0;
	}
}

class SupportArm : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Support Arm (Platform)
		+NOINTERACTION
		+MOVEWITHSECTOR
		Height 0;
		Radius 0;
		RenderRadius 256.0;
	}
}

class SupportArm2 : SupportArm
{
	Default
	{
		//$Title Support Arm (Panel Back)
	}
}

class SupportArmGroup : SupportArm
{
	Default
	{
		//$Title Support Arm (Panel Back, 2x3 group)
	}
}

class SupportArmBase : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Support Arm Component (Base)
		+MOVEWITHSECTOR
		+NOGRAVITY
		+SOLID
		Height 4;
		Radius 4;
		RenderRadius 256.0;
	}
}

class SupportArmLower : SupportArmBase
{
	Default
	{
		//$Title Support Arm Component (Lower)
	}
}

class SupportArmUpper : SupportArmBase
{
	Default
	{
		//$Title Support Arm Component (Upper)
	}
}

class SupportArmAttachment : SupportArmBase
{
	Default
	{
		//$Title Support Arm Component (Attachment)
	}
}

class WalkwaySegment : PortalActor
{
	bool user_blockingrails;

	Property BlockingRails:user_blockingrails;

	Default
	{
		//$Category Portal/Decorations
		//$Title Walkway
		+SOLID
		+NOGRAVITY
		+SHOOTABLE
		+NOBLOOD
		+INVULNERABLE
		+NODAMAGE
		+DONTTHRUST
		+NOTAUTOAIMED
		Height 1;
		Radius 28;
		RenderRadius 256.0;
		PortalActor.StepSound "footsteps/grate";
		//WalkwaySegment.BlockingRails True;
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", -24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", -24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 12.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentOpenSide : WalkwaySegment
{
	Default
	{
		//$Title Walkway (Open on one side)
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", -24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", -24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentOpenSide2 : WalkwaySegment
{
	Default
	{
		//$Title Walkway (Open on one side - no rail)
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", -24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentOpenSides : WalkwaySegment
{
	Default
	{
		//$Title Walkway (Open on both sides)
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", -24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", -24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentOpenSides2 : WalkwaySegment
{
	Default
	{
		//$Title Walkway (Open on both sides - no rail)
	}

	override void SpawnBlocks() {}
}

class WalkwaySegmentEnd : WalkwaySegment
{
	Default
	{
		//$Title Walkway End (Closed with railing)
		-SOLID
	}

	override void SpawnBlocks()
	{
		// Add walkable blocks
		A_SpawnItemEx ("Block36x1", -18.0, -18.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block36x1", -18.0, 18.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);

		// Frame the railings
		A_SpawnItemEx ("RailBlock", -24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", -24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", 4.0, -24.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 4.0, -12.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 4.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 4.0, 12.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 4.0, 24.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentOpenEnd : WalkwaySegmentEnd
{
	Default
	{
		//$Title Walkway End (Open)
	}

	override void SpawnBlocks()
	{
		// Add walkable blocks
		A_SpawnItemEx ("Block36x1", -18.0, -18.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block36x1", -18.0, 18.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);

		// Frame the railings
		A_SpawnItemEx ("RailBlock", -24.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", -24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentCorner : WalkwaySegment
{
	Default
	{
		//$Title Walkway Corner
	}

	override void SpawnBlocks()
	{
		// Frame the railings
		A_SpawnItemEx ("RailBlock", -24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -12.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 0.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 12.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 24.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", 36.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 36.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", -36.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, -24.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, -12.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 12.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 24.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentTee : WalkwaySegment
{
	Default
	{
		//$Title Walkway Tee
	}

	override void SpawnBlocks()
	{
		// Add walkable blocks
		A_SpawnItemEx ("Block32x1", 48.0, -8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", 48.0, 8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", -8.0, -48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", 8.0, -48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", -8.0, 48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", 8.0, 48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);

		// Frame the railings
		A_SpawnItemEx ("RailBlock", 36.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 36.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);

		A_SpawnItemEx ("RailBlock", -36.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, -24.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, -12.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 0.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 12.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 24.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WalkwaySegmentIntersection : WalkwaySegment
{
	Default
	{
		//$Title Walkway Intersection
	}

	override void SpawnBlocks()
	{
		// Add walkable blocks
		A_SpawnItemEx ("Block32x1", -48.0, -8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", -48.0, 8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", 48.0, -8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", 48.0, 8.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", -8.0, -48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", 8.0, -48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", -8.0, 48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("Block32x1", 8.0, 48.0, 0.0, 0, 0, 0, 0, SXF_SETMASTER);

		// Frame the railings
		A_SpawnItemEx ("RailBlock", -36.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 48.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", -36.0, 60.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 36.0, -60.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 36.0, -48.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 36.0, -36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
		A_SpawnItemEx ("RailBlock", 36.0, 36.0, 12.0, 0, 0, 0, 0, SXF_SETMASTER);
	}
}

class WallPanel : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Wall Panel (Corridor)
		+SOLID
		+NOGRAVITY
		+MOVEWITHSECTOR
		Height 56;
		Radius 8;
		RenderRadius 256.0;
		PortalActor.GlowColor 0x161414;
		PortalActor.GlowOffsetZ 48.0;
		PortalActor.GlowRadius 48.0;
		PortalActor.GlowSpotLight True;
		PortalActor.GlowOuterAngle 60;
	}

	override void PostBeginPlay()
	{
		switch (user_variant)
		{
			case 0:
			case 6:
				glowcolor = 0x52484E;
				break;
			case 5:
				break;
			case 4:
				glowcolor = 0x221a02;
				break;
			case 7:
				glowcolor = 0x0021C02;
				break;
			case 8:
				glowcolor = 0x06ff02;
				break;
		}

		Super.PostBeginPlay();
	}
}

class Frame32 : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Window Frame (32 wide)
		+NOGRAVITY
		+MOVEWITHSECTOR
		Height 0;
		Radius 0;
		RenderRadius 256.0;
	}
}

class Frame64 : Frame32
{
	Default
	{
		//$Title Window Frame (64 wide)
	}
}

class Frame112 : Frame32
{
	Default
	{
		//$Title Window Frame (112 wide)
	}
}

class Frame16 : Frame32
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Window Frame (16 wide)
	}
}

class WallPipe8 : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Wall Pipe (8 wide)
		+NOGRAVITY
		+MOVEWITHSECTOR
		Height 0;
		Radius 0;
		RenderRadius 64.0;
	}
}

class WallPipe16 : WallPipe8
{
	Default
	{
		//$Title Wall Pipe (16 wide)
	}
}

class WallPipe24 : WallPipe8
{
	Default
	{
		//$Title Wall Pipe (24 wide)
	}
}

class WallPipe32 : WallPipe8
{
	Default
	{
		//$Title Wall Pipe (32 wide)
	}
}

class WallBox : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Wall Box 1
		+NOGRAVITY
		+MOVEWITHSECTOR
		Height 0;
		Radius 0;
		RenderRadius 64.0;
	}
}

class WallBox2 : WallBox
{
	Default
	{
		//$Title Wall Box 2
	}
}

class WallBox3 : WallBox
{
	Default
	{
		//$Title Wall Box 3
	}
}

class Clock : PortalActor
{
	Actor s, m, h;
	TimeHandler handler;
	int time, seconds, smoothtics;

	Default
	{
		//$Title Wall Clock (Analog)
		+NOGRAVITY
		+MOVEWITHSECTOR
		RenderStyle "Translucent";
		Alpha 0.99999;
		Height 0;
		Radius 0;
	}

	override void PostBeginPlay()
	{
		s = Spawn("ClockHand_S", pos);
		if (s) { s.master = self; }

		m = Spawn("ClockHand_M", pos);
		if (m) { m.master = self; }

		h = Spawn("ClockHand_H", pos);
		if (h) { h.master = self; }

		handler = TimeHandler(EventHandler.Find("TimeHandler"));

		if (bStandStill) { time = Random(0, 43200 * 35); }

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (!bStandStill)
		{
			if (handler)
			{
				time = handler.time[consoleplayer];

				int hours = SystemTime.Format("%I", time).ToInt(10);
				int minutes = SystemTime.Format("%M", time).ToInt(10);
				int newseconds = SystemTime.Format("%S", time).ToInt(10);

				if (newseconds != seconds)
				{
					seconds = newseconds;
					smoothtics = 0;
				}

				time = (hours * 3600 + minutes * 60 + seconds) * 35 + smoothtics++;
			}
			else { time = level.time; }
		}

		if (s) { s.roll = -360.0 * time / (35 * 60); }
		if (m) { m.roll = -360.0 * time / (35 * 3600); }
		if (h) { h.roll = -360.0 * time / (35 * 43200); }

		Super.Tick();
	}
}

class ClockHand_S : Actor
{
	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+NOTONAUTOMAP
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
	}

	override void Tick()
	{
		if (master)
		{
			pitch = master.pitch;
			angle = master.angle;
			if (pos != master.pos) { SetOrigin(master.pos, true); }
		}

		Super.Tick();
	}
}

class ClockHand_M : ClockHand_S {}
class ClockHand_H : ClockHand_S {}

class CeilingVent : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Vent (Ceiling)
		+NOGRAVITY
		+MOVEWITHSECTOR
		Height 0;
		Radius 0;
		RenderRadius 64.0;
	}
}

class ComputerUnit : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Computer (Medium)
		+SOLID
		Height 54;
		Radius 12;
		PortalActor.GlowColor 0x161414;
		PortalActor.GlowOffsetZ 48.0;
		PortalActor.GlowRadius 48.0;
		PortalActor.GlowSpotLight True;
		PortalActor.GlowOuterAngle 45;
	}

	override void PostBeginPlay()
	{
		switch (user_variant)
		{
			case 0:
				glowcolor = 0x52484E;
				break;
			case 3:
				glowcolor = 0x2C1802;
				break;
			case 4:
				glowcolor = 0x0021C02;
				break;
			case 5:
				glowcolor = 0x06ff02;
				break;
		}

		Super.PostBeginPlay();
	}
}

class ComputerUnit2 : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Computer (Large)
		+SOLID
		Height 66;
		Radius 16;
		PortalActor.GlowOffsetZ 54.0;
		PortalActor.GlowRadius 64.0;
		PortalActor.GlowSpotLight True;
		PortalActor.GlowOuterAngle 45;
	}

	override void PostBeginPlay()
	{
		switch (user_variant)
		{
			case 0:
				glowcolor = 0x874644;
				SetGlow("LowerGlow", 0x52484E, 32.0, 1.0, glowx, glowy, 27.0, glowouterangle, glowpitchoffset);
				break;
			case 1:
				glowz = 60.0;
				glowradius = 32.0;
				glowcolor = 0x52484E;
				SetGlow("LowerGlow", glowcolor, 48.0, 1.0, glowx, glowy, 18.0, glowouterangle, glowpitchoffset);
				break;
			case 2:
				glowcolor = 0x874644;
				break;
		}

		Super.PostBeginPlay();
	}

	override void Deactivate(Actor activator)
	{
		A_RemoveLight("LowerGlow");

		Super.Deactivate(activator);
	}
}

class PC : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Computer (PC)
		+SOLID
		+NOGRAVITY
		Height 20;
		Radius 8;
	}
}

class PCMouse : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Computer Mouse
		+SOLID
		+NOGRAVITY
		Height 2;
		Radius 4;
	}
}

class PCKeyboard : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Computer Keyboard
		+SOLID
		+NOGRAVITY
		Height 2;
		Radius 8;
	}
}

class Fan : PortalActor
{
	Array<Actor> blades;
	double user_speed;

	Property FanSpeed:user_speed;

	Default
	{
		//$Category Portal/Decorations
		+NOGRAVITY
		Height 8;
		Radius 32;
		Fan.FanSpeed 3.0;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		for (int a = 0; a < 360; a += 45)
		{
			Actor mo = Spawn("FanBlade", pos);
			if (mo)
			{
				mo.angle = angle;
				mo.pitch = pitch;
				mo.roll = a;
				mo.scale = scale;
				blades.Push(mo);
			}
		}
	}

	override void Tick()
	{
		if (IsFrozen()) { return; }

		if (!bDormant && user_speed > 0)
		{
			for (int b = 0; b < blades.Size(); b++)
			{
				blades[b].roll += user_speed;
			}
		}

		Super.Tick();
	}
}

class FanBlade : PortalActor
{
	Default
	{
		+DORMANT
		+NOINTERACTION
		+NOGRAVITY
		-SOLID
		Height 1;
		Radius 2;
	}
}

class Support : PortalActor
{
	Default
	{
		//$Category Portal/Decorations
		//$Title Wire Support Beam
		+SOLID
		+NOGRAVITY
		Height 14;
		Radius 9;
	}
}