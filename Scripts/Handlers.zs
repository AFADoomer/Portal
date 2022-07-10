class OverlayItem
{
	Actor mo;
	String icon;
	double alpha;
	color clr;
	int type;
}

class OverlayHandler : EventHandler
{
	Array<OverlayItem> OverlayItems;

	override void WorldThingDestroyed(WorldEvent e)
	{
		int i = FindItem(e.Thing);

		if (i < OverlayItems.Size())
		{
			OverlayItems.Delete(i, 1);
			OverlayItems.ShrinkToFit();
		}
	}

	uint FindItem(Actor mo) // Helper function to find a thing in a child class (Used in place of CompassItems.Find(mo) since the mo is nested in a CompassIcon object
	{
		for (int i = 0; i < OverlayItems.Size(); i++)
		{
			if (OverlayItems[i] && OverlayItems[i].mo == mo) { return i; }
		}
		return OverlayItems.Size();
	}

	void AddItem(Actor thing, String iconName = "", color clr = 0xDE1B15, double alpha = 1.0, int type = 0)
	{
		if (!thing) { return; }

		int i = FindItem(thing);
		if (i < OverlayItems.Size()) // If it's already there, just update the properties
		{
			OverlayItems[i].icon = iconName;
			OverlayItems[i].alpha = alpha;
			OverlayItems[i].clr = clr;
			OverlayItems[i].type = type;
		}
		else
		{
			OverlayItem item = New("OverlayItem");
			item.mo = thing;
			item.icon = iconName;
			item.alpha = alpha;
			item.clr = clr;
			item.type = type;

			OverlayItems.Push(item);
		}
	}

	static void Add(Actor thing, String iconName = "", int actorTID = 0, color clr = 0xDE1B15, double alpha = 1.0, int type = 0)
	{
		if (iconName == "") { return; }

		if (!thing || actorTID)
		{
			if (actorTID)
			{
				let it = level.CreateActorIterator(actorTID, "Actor");
				Actor mo;

				while (mo = Actor(it.Next()))
				{
					Add(mo, iconName, 0, clr, alpha, type); // Add each thing that has a matching TID
				}
			}

			return; // If no thing was passed, silently fail here
		} 

		OverlayHandler handler = OverlayHandler(EventHandler.Find("OverlayHandler"));
		if (!handler) { return; } // If no handler was found (somehow), silently fail

		handler.AddItem(thing, iconName, clr, alpha, type);
	}

	static void Remove(Actor thing)
	{
		if (!thing) { return; } // If no thing was passed, silently fail

		OverlayHandler handler = OverlayHandler(EventHandler.Find("OverlayHandler"));
		if (!handler) { return; }

		int i = handler.FindItem(thing);

		if (i < handler.OverlayItems.Size())
		{
			handler.OverlayItems[i].Destroy();
			handler.OverlayItems.Delete(i, 1);
			handler.OverlayItems.ShrinkToFit();
		}
	}

	override void RenderUnderlay( RenderEvent e )
	{
		PlayerInfo p = players[consoleplayer];

		if (!p || !p.mo || (p.cheats & CF_CHASECAM) || automapactive) { return; }

		for (int i = 0; i < OverlayItems.Size(); i++)
		{
			Actor mo = OverlayItems[i].mo;
			if (!mo) continue;

			double dist = p.mo.Distance3D(mo);

			Vector3 worldpos = e.viewpos + level.Vec3Diff(e.viewpos, mo.pos); // World position of object, offset from viewpoint
			Vector3 screenpos = PortalCoordUtil.WorldToScreen(worldpos, e.viewpos, e.viewpitch, e.viewangle, e.viewroll, p.fov); // Translate that to the screen, using the viewpoint's info

			if (screenpos.z > 1 || screenpos.z < -1) { continue; } // If the coordinates are off the screen, then skip drawing this item

			Vector2 drawpos = PortalCoordUtil.ToViewport(screenpos);

			TextureID image = TexMan.CheckForTexture(OverlayItems[i].icon, TexMan.Type_Any);

			Vector2 dimensions = TexMan.GetScaledSize(image) * vid_scalefactor;
			dimensions /= dist / 512 * p.fov / 90; // Scale with fov to account for zooming

			if (OverlayItems[i].type == 1)
			{
				double h = abs(Actor.deltaangle(p.mo.AngleTo(mo), mo.angle));
				if (h > 90) { h = 180 - h; }
				dimensions.x *= (1 - h / 90);

				double v = abs((mo.pitch - PitchTo(p.mo, mo)) / 2);
				dimensions.y *= (1 - v / 90);
			}

			color clr = OverlayItems[i].clr;
			double alpha = OverlayItems[i].alpha;

			screen.DrawTexture (image, false, drawpos.x, drawpos.y, DTA_DestWidthF, dimensions.x, DTA_DestHeightF, dimensions.y, DTA_AlphaChannel, true, DTA_FillColor, clr & 0xFFFFFF, DTA_Alpha, alpha, DTA_CenterOffset, true);
		}
	}

	ui double PitchTo(Actor mo, Actor source = null, double zoffset = 0.0)
	{
		if (!source) { source = Actor(self); }
		if (!source) { return 0; }

		double distxy = max(source.Distance2D(mo), 1);
		double distz = source.pos.z + zoffset - mo.pos.z;

		return atan(distz / distxy);
	}
}

class ShaderControl : Inventory
{
	string ShaderToControl;

	Property Shader:ShaderToControl;

	Default
	{
		Inventory.MaxAmount 0x7fffffff;
	}

	virtual ui void SetUniforms(PlayerInfo p, RenderEvent e) {}
}

class ShaderHandler : StaticEventHandler
{
	override void RenderOverlay(RenderEvent e)
	{
		PlayerInfo p = players[consoleplayer];
		ThinkerIterator shaderIter = ThinkerIterator.Create("ShaderControl");

		ShaderControl shaderControl;

		while (shaderControl = ShaderControl(shaderIter.Next()))
		{
			if (shaderControl.Owner && shaderControl.Owner == p.mo && shaderControl.amount > 0)
			{
				Shader.SetUniform1f(p, shaderControl.ShaderToControl, "timer", gametic + e.FracTic);
				Shader.SetUniform1f(p, shaderControl.ShaderToControl, "amount", shaderControl.amount);
				Shader.SetUniform1f(p, shaderControl.ShaderToControl, "alpha", shaderControl.alpha);
				shaderControl.SetUniforms(p, e);
				Shader.SetEnabled(p, shaderControl.ShaderToControl, true);
			}
			else
			{
				Shader.SetEnabled(p, shaderControl.ShaderToControl, false);
			}
		}
	}
}

class ScreenShake : ShaderControl
{
	int holdtarget;

	Default
	{
		ShaderControl.Shader "shakeshader";
	}

	override void SetUniforms(PlayerInfo p, RenderEvent e)
	{
		Shader.SetUniform1f(p, ShaderToControl, "speed", amount / 4.0);
	}
}

class SectorDamageItem
{
	Sector sec;
	int damageamount, olddamageamount, damageinterval, olddamageinterval, end;
	Name damagetype, olddamagetype;
}

// Setting sector damage type and amount with a fixed duration
class SectorDamageHandler : EventHandler
{
	Array<SectorDamageItem> SectorDamageItems;

	static void SetDamage(Sector sec, int damageamount, Name damagetype = 'None', int damageinterval = 1, int duration = 35)
	{
		SectorDamageHandler handler = SectorDamageHandler(EventHandler.Find("SectorDamageHandler"));
		if (!handler) { return; } // If no handler was found (somehow), silently fail

		handler.AddItem(sec, damageamount, damagetype, damageinterval, duration);
	}

	uint FindItem(Sector sec) // Helper function to find a thing in a child class since the target item is nested in a wrapper object (that shoud be a struct... but, ZScript limitations)
	{
		for (int i = 0; i < SectorDamageItems.Size(); i++)
		{
			if (SectorDamageItems[i] && SectorDamageItems[i].sec == sec) { return i; }
		}
		return SectorDamageItems.Size();
	}

	void AddItem(Sector sec, int damageamount, Name damagetype = 'None', int damageinterval = 1, int duration = 35)
	{
		if (!sec) { return; }

		int i = FindItem(sec);
		if (i < SectorDamageItems.Size()) // If it's already there, just update the properties
		{
			SectorDamageItems[i].damageamount = damageamount;
			SectorDamageItems[i].damageinterval = damageinterval;
			SectorDamageItems[i].damagetype = damagetype;
			SectorDamageItems[i].end = level.time + duration;
		}
		else
		{
			SectorDamageItem item = New("SectorDamageItem");
			item.sec = sec;

			item.olddamageamount = sec.damageamount;
			item.olddamageinterval = sec.damageinterval;
			item.olddamagetype = sec.damagetype;

			item.damageamount = damageamount;
			item.damageinterval = damageinterval;
			item.damagetype = damagetype;

			item.end = level.time + duration;

			SectorDamageItems.Push(item);
		}
	}

	override void WorldTick()
	{
		for (int i = 0; i < SectorDamageItems.Size(); i++)
		{
			if (SectorDamageItems[i])
			{
				if (level.time > SectorDamageItems[i].end)
				{
					SectorDamageItems[i].sec.damageamount = SectorDamageItems[i].olddamageamount;
					SectorDamageItems[i].sec.damageinterval = SectorDamageItems[i].olddamageinterval;
					SectorDamageItems[i].sec.damagetype = SectorDamageItems[i].olddamagetype;

					SectorDamageItems.Delete(i);
				}
				else
				{
					SectorDamageItems[i].sec.damageamount = SectorDamageItems[i].damageamount;
					SectorDamageItems[i].sec.damageinterval = SectorDamageItems[i].damageinterval;
					SectorDamageItems[i].sec.damagetype = SectorDamageItems[i].damagetype;
				}
			}
		}
	}
}

class TimeHandler : EventHandler
{
	int time[MAXPLAYERS];

	override void UiTick()
	{
		EventHandler.SendNetworkEvent("time", SystemTime.Now());
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (!e.IsManual && e.Name == "time" && e.player == consoleplayer) { time[consoleplayer] = e.args[0]; }
	}	
}