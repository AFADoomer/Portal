class Cube : CarryActor
{
	Default
	{
		//$Category Portal/Cubes
		//$Sprite "UNKNB0"
		-NODAMAGE
		Health 100;
		Height 22;
		Radius 14;
		Mass 55;
		BounceSound "cube/bounce";
		WallBounceSound "cube/bounce";
		CarryActor.Fizzle True;
		CarryActor.SlideSound "cube/slide";
	}

	States
	{
		Spawn:
			UNKN # -1;
			Stop;
		Death:
			Goto Fizzle;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER); // Used to set actors that can activate buttons.
		Super.BeginPlay();
	}
}

class LaserCube : Cube
{
	Actor lasersource, interior, logos, glow, flare;
	bool laserhit;
	color lasercolor;

	Property LaserColor:lasercolor;

	Default
	{
		//$Title Laser Cube
		LaserCube.LaserColor 0xFF0000;
	}

	override void PostBeginPlay()
	{
		while (!interior) { interior = Spawn("LaserCubeInterior", pos); }
		interior.master = self;

		while (!glow) { glow = Spawn("LaserCubeInterior", pos); }
		glow.master = self;
		glow.A_SetRenderStyle(glow.Default.alpha, STYLE_AddStencil);

		while (!logos) { logos = Spawn("LaserCubeLogos", pos); }
		logos.master = self;

		while (!flare) { flare = Spawn("Flare", pos); }
		flare.master = self;
		
		while (!lasersource) { lasersource = Spawn("LaserSpot", pos); }
		lasersource.Deactivate(self);

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (lasersource)
		{
			lasersource.master = self;
			lasersource.SetOrigin(pos, false);
			lasersource.angle = angle;

			if (laserhit)
			{
				Spawn("LaserHit", pos);
				lasersource.Activate(self);

				A_AttachLight("LaserLight", DynamicLight.PointLight, lasercolor, int(radius), int(radius), DynamicLight.LF_ATTENUATE);
				if (interior.alpha < interior.Default.alpha) { interior.alpha = min(interior.Default.alpha, interior.alpha + 0.05); }
				glow.alpha = max(0.0, interior.alpha - interior.Default.alpha / 2);
				glow.SetShade(lasercolor);

				flare.alpha = 0.7 + FRandom(-0.2, 0.2);
				flare.scale.x = flare.Default.scale.x * FRandom(0.2, 0.8) * scale.x;
				flare.scale.y = flare.Default.scale.y * FRandom(0.2, 0.8) * scale.y;
				flare.SetXYZ(pos);
			}
			else
			{
				lasersource.Deactivate(self);
				A_RemoveLight("LaserLight");
				if (interior.alpha > interior.Default.alpha / 3) { interior.alpha = max(interior.Default.alpha / 3, interior.alpha - 0.05); }
				glow.alpha = max(0.0, interior.alpha - interior.Default.alpha / 2);
				flare.alpha = 0.0;
			}
		}

		laserhit = false;

		Super.Tick();
	}	

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (inflictor is "LaserBeam" && source != self)
		{
			lasercolor = LaserBeam(inflictor).lasercolor;
			if (!lasercolor) { lasercolor = Default.lasercolor; }
			laserhit = true;
		}

		return 0;
	}
}

class LaserCubeInterior : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		Renderstyle "Add";
		Alpha 0.7;
		Species "Laser";
	}

	override void Tick()
	{
		if (master)
		{
			angle = master.angle;
			pitch = master.pitch;
			roll = master.roll;

			if (LaserCube(master))
			{
				SetOrigin(master.pos - (0, 0, LaserCube(master).zoffset) * scale.y, true);
			}
			else
			{
				SetOrigin(master.pos, true);
			}
		}
		else { Destroy(); }

		Super.Tick();
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
	}
}

class LaserCubeLogos : LaserCubeInterior {}