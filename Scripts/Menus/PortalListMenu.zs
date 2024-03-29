// Base class that handles drawing informational text under menu entries
class PortalListMenu : ListMenu
{
	Font accentfont;
	String lookupBase;
	int itemCount;

	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);

		accentfont = Font.GetFont("Tre14");
		if (!accentfont) { accentfont = SmallFont; }

		// Allow generic lookups - strip "menu" off of the menu name, and use that stub as the lookup base (e.g., SKILL, EPISODE, etc.)
		String MenuName = String.Format("%s", mDesc.mMenuName).MakeUpper();
		MenuName.Replace("MENU", "");

		lookupBase = MenuName;
	}

	override void Drawer()
	{
		// Draw the text description for the currently selected item
		if (mDesc.mSelectedItem > -1 && mDesc.mItems[mDesc.mSelectedItem] is "ListMenuItemSelectable")
		{
			DrawItemText(mDesc.mSelectedItem, breakWidth:Screen.GetWidth() - 180);
		}

		double menubase = Screen.GetHeight() - mDesc.mLinespacing;

		for(int j = 0; j < mDesc.mItems.Size(); j++)
		{
			if (mDesc.mItems[j].Selectable()) { menubase -= mDesc.mLinespacing; }
		}
		bool selected;

		for(int i = 0; i < mDesc.mItems.Size(); i++)
		{
			selected = mDesc.mSelectedItem == i;
			let item = mDesc.mItems[i];

			if (item.mEnabled)
			{
				if (item is "ListMenuItemTextItem")
				{
					let this = ListMenuItemTextItem(item);

					let font = generic_ui? NewSmallFont : this.mFont;
					screen.DrawText(font, selected ? this.mColorSelected : this.mColor, this.GetX(), menubase + this.GetY(), this.mText);
				}
				else if (item is "ListMenuItemStaticText")
				{
					let this = ListMenuItemStaticText(item);

					if (this.mText.Length() != 0)
					{
						let font = generic_ui? NewSmallFont : this.mFont;

						String text = Stringtable.Localize(this.mText);

						int x = int((this.mCentered ? 20 : 0) + this.GetX());
						int y = int(menubase + this.GetY());

						if (this.mCentered) { text = text.MakeUpper(); }
						screen.DrawText(font, this.mColor, x, y, text);
					}
				}
				else if (item is "ListMenuItemStaticPatch")
				{
					let this = ListMenuItemStaticPatch(item);

					if (!this.mTexture.Exists()) { return; }

					Vector2 vec = TexMan.GetScaledSize(this.mTexture);

					double x = this.GetX();
					if (this.mCentered) { x -= vec.X / 2; }

					screen.DrawTexture(this.mTexture, true, int(x), this.GetY(), DTA_Clean, true);
				}

				if (selected)
				{
					double alpha = sin(Menu.MenuTime() * 10) / 2 + 0.5;
					screen.DrawText(NewSmallFont, OptionMenuSettings.mFontColorSelection, item.GetX() + mDesc.mSelectOfsX, menubase + item.GetY() + mDesc.mSelectOfsY, "►", DTA_Alpha, alpha);
				}
			}
		}

		Menu.Drawer();
	}

	void DrawItemText(int index, double x = -1, double y = -1, double alpha = 0.6, int breakWidth = 300, double scale = 1.0)
	{
		if (index < 0) { return; }

		double fontheight = accentfont.GetHeight() * scale;

		if (x < 0) { x = 160; }
		if (y < 0) { y = Screen.GetHeight() - (mDesc.mItems.Size() + 1 - index) * mDesc.mLinespacing; }

		String text;

		let item = mDesc.mItems[index];

		if (item is "ListMenuItemTextItem")
		{
			text = ListMenuItemTextItem(item).mText;
		}
		else if (item is "ListMenuItemPatchItem")
		{
			text = TexMan.GetName(ListMenuItemPatchItem(item).mTexture);
		}

		text.Replace(" ", "");

		String lookup = lookupBase .. "_" .. text;
		text = StringTable.Localize("$" .. lookup);
		if (text == lookup) { return; }

		BrokenLines message = accentfont.BreakLines(text, int(breakWidth / scale));

		int c = message.Count();

		y -= fontheight / 2;
		y += mDesc.mLinespacing / 2;

		for (int i = 0; i < c; i++)
		{
			screen.DrawText (accentfont, OptionMenuSettings.mFontColor, x / scale, y / scale, message.StringAt(i), DTA_Alpha, alpha, DTA_Clean, true, DTA_VirtualWidthF, Screen.GetWidth() / scale, DTA_VirtualHeightF, Screen.GetHeight() / scale);
			y += fontheight;
		}
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		switch (mkey)
		{
			case MKEY_Back:
				return Super.MenuEvent(mkey, fromcontroller);
			case MKEY_Enter:
				if (mDesc.mSelectedItem >= 0)
				{
					if (mDesc.mItems[mDesc.mSelectedItem].Activate()) { MenuSound("menu/choose"); }
				}
				return true;
			default:
				return Super.MenuEvent(mkey, fromcontroller);
		}
	}
}

class PortalSaveMenu : SaveMenu
{
	Font accentfont;
	String lookupBase;
	int itemCount;
	double menubase;

	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);

		accentfont = Font.GetFont("Tre14");
		if (!accentfont) { accentfont = SmallFont; }

		// Allow generic lookups - strip "menu" off of the menu name, and use that stub as the lookup base (e.g., SKILL, EPISODE, etc.)
		String MenuName = String.Format("%s", mDesc.mMenuName).MakeUpper();
		MenuName.Replace("MENU", "");

		lookupBase = MenuName;

		TopItem = 0;
		Selected = manager.ExtractSaveData (-1);
		UpdateSaveComment();

		menubase = mDesc.mLinespacing;
		savepictop = int(menubase) + 20;

		for(int j = 0; j < mDesc.mItems.Size(); j++)
		{
			savepictop += mDesc.mLinespacing;
		}

		savepicLeft = 30;
		savepicWidth = 425*screen.GetWidth() / 640;
		savepicHeight = 266*screen.GetHeight() / 400;

		FontScale = max(screen.GetHeight() / 480, 1);
		rowHeight = int(max((NewConsoleFont.GetHeight() + 1) * FontScale, 1));
		
		listboxLeft = savepicLeft + savepicWidth + 14 + 20;
		listboxTop = savepicTop;
		listboxWidth = screen.GetWidth() - listboxLeft - 30;
		int listboxHeight1 = screen.GetHeight() - listboxTop - 20;
		listboxRows = (listboxHeight1 - 1) / rowHeight;
		listboxHeight = listboxRows * rowHeight + 1;
		listboxRight = listboxLeft + listboxWidth;
//		listboxBottom = listboxTop + listboxHeight;

		commentLeft = savepicLeft;
		commentTop = savepicTop + savepicHeight + 16 + 20;
		commentWidth = savepicWidth;
		commentHeight = listboxHeight - savepicHeight - 16 - 20;
//		commentRight = commentLeft + commentWidth;
//		commentBottom = commentTop + commentHeight;
		commentRows = commentHeight / rowHeight;
	}

	override void Drawer()
	{
		bool isselected;

		for(int i = 0; i < mDesc.mItems.Size(); i++)
		{
			isselected = mDesc.mSelectedItem == i;
			let item = mDesc.mItems[i];

			if (item.mEnabled)
			{
				if (item is "ListMenuItemTextItem")
				{
					let this = ListMenuItemTextItem(item);

					let font = generic_ui? NewSmallFont : this.mFont;
					screen.DrawText(font, selected ? this.mColorSelected : this.mColor, this.GetX(), menubase + this.GetY(), this.mText);
				}
				else if (item is "ListMenuItemStaticText")
				{
					let this = ListMenuItemStaticText(item);

					if (this.mText.Length() != 0)
					{
						let font = generic_ui ? NewSmallFont : this.mFont;

						String text = Stringtable.Localize(this.mText);

						int x = int((this.mCentered ? 20 : 0) + this.GetX());
						int y = int(menubase + this.GetY());

						screen.DrawText(font, this.mColor, x, y, text);
					}
				}

				if (isselected)
				{
					double alpha = sin(Menu.MenuTime() * 10) / 2 + 0.5;
					screen.DrawText(NewSmallFont, OptionMenuSettings.mFontColorSelection, item.GetX() + mDesc.mSelectOfsX, menubase + item.GetY() + mDesc.mSelectOfsY, "►", DTA_Alpha, alpha);
				}
			}
		}

		Menu.Drawer();

		SaveGameNode node;
		int i;
		int j;
		bool didSeeSelected = false;

		// Draw picture area
		if (gameaction == ga_loadgame || gameaction == ga_loadgamehidecon || gameaction == ga_savegame)
		{
			return;
		}

		Screen.Dim(0x000000, 0.5, savepicLeft - 10, savepicTop - 10, savepicWidth + 20, savepicHeight + 20);

		if (!manager.DrawSavePic(savepicLeft, savepicTop, savepicWidth, savepicHeight))
		{
			if (manager.SavegameCount() > 0)
			{
				String text = (Selected == -1 || !manager.GetSavegame(Selected).bOldVersion)? Stringtable.Localize("$MNU_NOPICTURE") : Stringtable.Localize("$MNU_DIFFVERSION");
				int textlen = NewSmallFont.StringWidth(text);

				screen.DrawText (NewSmallFont, Font.CR_GOLD, savepicLeft+(savepicWidth-textlen)/2, savepicTop+(savepicHeight-rowHeight)/2, text);
			}
		}

		// Draw comment area
		Screen.Dim(0x000000, 0.5, commentLeft - 10, commentTop - 10, commentWidth + 20, commentHeight + 20);

		int numlinestoprint = min(commentRows, BrokenSaveComment? BrokenSaveComment.Count() : 0);
		for(int i = 0; i < numlinestoprint; i++)
		{
			screen.DrawText(NewConsoleFont, Font.CR_ORANGE, commentLeft / FontScale, (commentTop + rowHeight * i) / FontScale, BrokenSaveComment.StringAt(i),
				DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
		}
		

		// Draw file area
		Screen.Dim(0x000000, 0.5, listboxLeft - 10, listboxTop - 10, listboxWidth + 20, listboxHeight + 20);

		if (manager.SavegameCount() == 0)
		{
			String text = Stringtable.Localize("$MNU_NOFILES");
			int textlen = int(NewConsoleFont.StringWidth(text) * FontScale);

			screen.DrawText (NewConsoleFont, Font.CR_GOLD, (listboxLeft+(listboxWidth-textlen)/2) / FontScale, (listboxTop+(listboxHeight-rowHeight)/2) / FontScale, text, 
				DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
			return;
		}

		j = TopItem;
		for (i = 0; i < listboxRows && j < manager.SavegameCount(); i++)
		{
			int colr;
			node = manager.GetSavegame(j);
			if (node.bOldVersion)
			{
				colr = Font.CR_RED;
			}
			else if (node.bMissingWads)
			{
				colr = Font.CR_YELLOW;
			}
			else if (j == Selected)
			{
				colr = Font.CR_WHITE;
			}
			else
			{
				colr = Font.CR_TAN;
			}

			screen.SetClipRect(listboxLeft, listboxTop+rowHeight*i, listboxRight, listboxTop+rowHeight*(i+1));
			
			if (j == Selected)
			{
				screen.Clear (listboxLeft, listboxTop+rowHeight*i, listboxRight, listboxTop+rowHeight*(i+1), mEntering ? Color(255,255,0,0) : Color(255,0,0,255));
				didSeeSelected = true;
				if (!mEntering)
				{
					screen.DrawText (NewConsoleFont, colr, (listboxLeft+1) / FontScale, (listboxTop+rowHeight*i + FontScale) / FontScale, node.SaveTitle, 
						DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
				}
				else
				{
					String s = mInput.GetText() .. NewConsoleFont.GetCursor();
					int length = int(NewConsoleFont.StringWidth(s) * FontScale);
					int displacement = min(0, listboxWidth - 2 - length);
					screen.DrawText (NewConsoleFont, Font.CR_WHITE, (listboxLeft + 1 + displacement) / FontScale, (listboxTop+rowHeight*i + FontScale) / FontScale, s, 
						DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
				}
			}
			else
			{
				screen.DrawText (NewConsoleFont, colr, (listboxLeft+1) / FontScale, (listboxTop+rowHeight*i + FontScale) / FontScale, node.SaveTitle, 
					DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
			}
			screen.ClearClipRect();
			j++;
		}
	}
}

class PortalLoadMenu : LoadMenu
{
	Font accentfont;
	String lookupBase;
	int itemCount;
	double menubase;

	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);

		accentfont = Font.GetFont("Tre14");
		if (!accentfont) { accentfont = SmallFont; }

		// Allow generic lookups - strip "menu" off of the menu name, and use that stub as the lookup base (e.g., SKILL, EPISODE, etc.)
		String MenuName = String.Format("%s", mDesc.mMenuName).MakeUpper();
		MenuName.Replace("MENU", "");

		lookupBase = MenuName;

		TopItem = 0;
		Selected = manager.ExtractSaveData (-1);
		UpdateSaveComment();

		menubase = mDesc.mLinespacing;
		savepictop = int(menubase) + 20;

		for(int j = 0; j < mDesc.mItems.Size(); j++)
		{
			savepictop += mDesc.mLinespacing;
		}

		savepicLeft = 30;
		savepicWidth = 425*screen.GetWidth() / 640;
		savepicHeight = 266*screen.GetHeight() / 400;

		FontScale = max(screen.GetHeight() / 480, 1);
		rowHeight = int(max((NewConsoleFont.GetHeight() + 1) * FontScale, 1));
		
		listboxLeft = savepicLeft + savepicWidth + 14 + 20;
		listboxTop = savepicTop;
		listboxWidth = screen.GetWidth() - listboxLeft - 30;
		int listboxHeight1 = screen.GetHeight() - listboxTop - 20;
		listboxRows = (listboxHeight1 - 1) / rowHeight;
		listboxHeight = listboxRows * rowHeight + 1;
		listboxRight = listboxLeft + listboxWidth;
//		listboxBottom = listboxTop + listboxHeight;

		commentLeft = savepicLeft;
		commentTop = savepicTop + savepicHeight + 16 + 20;
		commentWidth = savepicWidth;
		commentHeight = listboxHeight - savepicHeight - 16 - 20;
//		commentRight = commentLeft + commentWidth;
//		commentBottom = commentTop + commentHeight;
		commentRows = commentHeight / rowHeight;
	}

	override void Drawer()
	{
		bool isselected;

		for(int i = 0; i < mDesc.mItems.Size(); i++)
		{
			isselected = mDesc.mSelectedItem == i;
			let item = mDesc.mItems[i];

			if (item.mEnabled)
			{
				if (item is "ListMenuItemTextItem")
				{
					let this = ListMenuItemTextItem(item);

					let font = generic_ui? NewSmallFont : this.mFont;
					screen.DrawText(font, selected ? this.mColorSelected : this.mColor, this.GetX(), menubase + this.GetY(), this.mText);
				}
				else if (item is "ListMenuItemStaticText")
				{
					let this = ListMenuItemStaticText(item);

					if (this.mText.Length() != 0)
					{
						let font = generic_ui ? NewSmallFont : this.mFont;

						String text = Stringtable.Localize(this.mText);

						int x = int((this.mCentered ? 20 : 0) + this.GetX());
						int y = int(menubase + this.GetY());

						screen.DrawText(font, this.mColor, x, y, text);
					}
				}

				if (isselected)
				{
					double alpha = sin(Menu.MenuTime() * 10) / 2 + 0.5;
					screen.DrawText(NewSmallFont, OptionMenuSettings.mFontColorSelection, item.GetX() + mDesc.mSelectOfsX, menubase + item.GetY() + mDesc.mSelectOfsY, "►", DTA_Alpha, alpha);
				}
			}
		}

		Menu.Drawer();

		SaveGameNode node;
		int i;
		int j;
		bool didSeeSelected = false;

		// Draw picture area
		if (gameaction == ga_loadgame || gameaction == ga_loadgamehidecon || gameaction == ga_savegame)
		{
			return;
		}

		Screen.Dim(0x000000, 0.5, savepicLeft - 10, savepicTop - 10, savepicWidth + 20, savepicHeight + 20);

		if (!manager.DrawSavePic(savepicLeft, savepicTop, savepicWidth, savepicHeight))
		{
			if (manager.SavegameCount() > 0)
			{
				String text = (Selected == -1 || !manager.GetSavegame(Selected).bOldVersion)? Stringtable.Localize("$MNU_NOPICTURE") : Stringtable.Localize("$MNU_DIFFVERSION");
				int textlen = NewSmallFont.StringWidth(text);

				screen.DrawText (NewSmallFont, Font.CR_GOLD, savepicLeft+(savepicWidth-textlen)/2, savepicTop+(savepicHeight-rowHeight)/2, text);
			}
		}

		// Draw comment area
		Screen.Dim(0x000000, 0.5, commentLeft - 10, commentTop - 10, commentWidth + 20, commentHeight + 20);

		int numlinestoprint = min(commentRows, BrokenSaveComment? BrokenSaveComment.Count() : 0);
		for(int i = 0; i < numlinestoprint; i++)
		{
			screen.DrawText(NewConsoleFont, Font.CR_ORANGE, commentLeft / FontScale, (commentTop + rowHeight * i) / FontScale, BrokenSaveComment.StringAt(i),
				DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
		}
		

		// Draw file area
		Screen.Dim(0x000000, 0.5, listboxLeft - 10, listboxTop - 10, listboxWidth + 20, listboxHeight + 20);

		if (manager.SavegameCount() == 0)
		{
			String text = Stringtable.Localize("$MNU_NOFILES");
			int textlen = int(NewConsoleFont.StringWidth(text) * FontScale);

			screen.DrawText (NewConsoleFont, Font.CR_GOLD, (listboxLeft+(listboxWidth-textlen)/2) / FontScale, (listboxTop+(listboxHeight-rowHeight)/2) / FontScale, text, 
				DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
			return;
		}

		j = TopItem;
		for (i = 0; i < listboxRows && j < manager.SavegameCount(); i++)
		{
			int colr;
			node = manager.GetSavegame(j);
			if (node.bOldVersion)
			{
				colr = Font.CR_RED;
			}
			else if (node.bMissingWads)
			{
				colr = Font.CR_YELLOW;
			}
			else if (j == Selected)
			{
				colr = Font.CR_WHITE;
			}
			else
			{
				colr = Font.CR_TAN;
			}

			screen.SetClipRect(listboxLeft, listboxTop+rowHeight*i, listboxRight, listboxTop+rowHeight*(i+1));
			
			if (j == Selected)
			{
				screen.Clear (listboxLeft, listboxTop+rowHeight*i, listboxRight, listboxTop+rowHeight*(i+1), mEntering ? Color(255,255,0,0) : Color(255,0,0,255));
				didSeeSelected = true;
				if (!mEntering)
				{
					screen.DrawText (NewConsoleFont, colr, (listboxLeft+1) / FontScale, (listboxTop+rowHeight*i + FontScale) / FontScale, node.SaveTitle, 
						DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
				}
				else
				{
					String s = mInput.GetText() .. NewConsoleFont.GetCursor();
					int length = int(NewConsoleFont.StringWidth(s) * FontScale);
					int displacement = min(0, listboxWidth - 2 - length);
					screen.DrawText (NewConsoleFont, Font.CR_WHITE, (listboxLeft + 1 + displacement) / FontScale, (listboxTop+rowHeight*i + FontScale) / FontScale, s, 
						DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
				}
			}
			else
			{
				screen.DrawText (NewConsoleFont, colr, (listboxLeft+1) / FontScale, (listboxTop+rowHeight*i + FontScale) / FontScale, node.SaveTitle, 
					DTA_VirtualWidthF, screen.GetWidth() / FontScale, DTA_VirtualHeightF, screen.GetHeight() / FontScale, DTA_KeepRatio, true);
			}
			screen.ClearClipRect();
			j++;
		}
	}
}

class PortalOptionMenu : OptionMenu
{
	override void Drawer()
	{
		Draw(OptionMenu(self), 20, 20);
	}

	static void Draw(OptionMenu current, int left, int spacing, Font accentfont = null)
	{
		if (!accentfont)
		{
			accentfont = Font.GetFont("Tre14");
			if (!accentfont) { accentfont = SmallFont; }
		}

		int x = left;
		int y = Screen.GetHeight() - 8 + current.mDesc.mPosition - OptionMenuSettings.mLinespacing;
		int indent = Screen.GetWidth() / 8;

		for(int j = 0; j < current.mDesc.mItems.Size(); j++)
		{
// Uncomment to bottom align menu
//			y = max(OptionMenuSettings.mLinespacing, y - OptionMenuSettings.mLinespacing);
			if (current.mDesc.mItems[j].Selectable()) { indent = max(indent, OptionWidth(current, Stringtable.Localize(current.mDesc.mItems[j].mLabel), accentfont)); }
		}
		y = OptionMenuSettings.mLinespacing * 4 / 3;

		indent += x;

		if (current.mDesc.mTitle.Length())
		{
			Menu parent = current.mParentMenu;

			String title = Stringtable.Localize(current.mDesc.mTitle) .. ":";

			while (parent)
			{
				if (OptionMenu(parent))
				{
					title = Stringtable.Localize(OptionMenu(parent).mDesc.mTitle) .. " / " .. title;

					parent = parent.mParentMenu;
				}
				else
				{
					parent = null;
				}
			}

			screen.DrawText (accentfont, OptionMenuSettings.mTitleColor, x + 10, 20, title);
			y += OptionMenuSettings.mLinespacing;
		}

		current.mDesc.mDrawTop = y;

		int ytop = y + current.mDesc.mScrollTop * OptionMenuSettings.mLinespacing;
// Uncomment to bottom align menu
//		int lastrow = screen.GetHeight() - OptionMenuSettings.mLinespacing;
		int lastrow = screen.GetHeight() - y;

		int i;
		for (i = 0; i < current.mDesc.mItems.Size() && y <= lastrow; i++)
		{
			// Don't scroll the uppermost items
			if (i == current.mDesc.mScrollTop)
			{
				i += current.mDesc.mScrollPos;
				if (i >= current.mDesc.mItems.Size()) break;	// skipped beyond end of menu 
			}

			bool isSelected = current.mDesc.mSelectedItem == i;

			let item = current.mDesc.mItems[i];

			if (item.mEnabled)
			{
				String label;

				if (item is "OptionMenuItemControlBase")
				{
					let this = OptionMenuItemControlBase(item);

					label = Stringtable.Localize(item.mLabel);
					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, this.mWaiting ? OptionMenuSettings.mFontColorHighlight : (isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor));

					String Description;
					int Key1, Key2;

					[Key1, Key2] = this.mBindings.GetKeysForCommand(this.GetAction());

					description = KeyBindings.NameKeys (Key1, Key2);

					if (description.Length())
					{
						DrawValue(current, description, indent, y, spacing, accentfont, Font.CR_WHITE);
					}
					else
					{
						DrawValue(current, "---", indent, y, spacing, accentfont, Font.CR_BLACK);
					}
				}
				else if (item is "OptionMenuItemOptionBase")
				{
					let this = OptionMenuItemOptionBase(item);

					label = Stringtable.Localize(item.mLabel);
					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor, this.isGrayed());

					int Selection = this.GetSelection();
					String text = StringTable.Localize(OptionValues.GetText(this.mValues, Selection));
					if (text.Length() == 0) text = "Unknown";

					if (item is "os_AnyOrAllOption")
					{
						DrawValue(current, text, accentfont.StringWidth(label) + 20, y, spacing, accentfont, OptionMenuSettings.mFontColorValue, this.isGrayed());	
					}
					else
					{
						DrawValue(current, text, indent, y, spacing, accentfont, OptionMenuSettings.mFontColorValue, this.isGrayed());
					}
				}
				else if (item is "OptionMenuSliderBase")
				{
					let this = OptionMenuSliderBase(item);

					label = Stringtable.Localize(item.mLabel);
					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor);

					if (item is "OptionMenuItemScaleSlider")
					{
						int Selection = int(this.GetSliderValue());
						if ((Selection == 0 || Selection == -1) && OptionMenuItemScaleSlider(this).mClickVal <= 0)
						{
							String text = Selection == 0 ? OptionMenuItemScaleSlider(this).TextZero : Selection == -1 ? OptionMenuItemScaleSlider(this).TextNegOne : "";
							DrawValue(current, text, indent, y, spacing, accentfont, OptionMenuSettings.mFontColorValue);
						}
						else
						{
							DrawSlider(current, this, indent, y, spacing, accentfont, this.mMin, this.mMax, this.GetSliderValue(), this.mShowValue, indent);
						}
					}
					else
					{
						DrawSlider(current, this, indent, y, spacing, accentfont, this.mMin, this.mMax, this.GetSliderValue(), this.mShowValue, indent);
					}
				}
				else if (item is "OptionMenuItemStaticTextSwitchable")
				{
					let this = OptionMenuItemStaticTextSwitchable(item);
					label = StringTable.Localize(this.mCurrent ? this.mAltText : this.mLabel);

					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor);
				}
				else if (item is "OptionMenuItemColorPicker")
				{
					let this = OptionMenuItemColorPicker(item);

					label = Stringtable.Localize(item.mLabel);
					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor);

					if (this.mCVar != null)
					{
						int box_x = indent + spacing;
						int box_y = y + 3;
						screen.Clear (box_x - 1, box_y - 1, box_x + 33, box_y + OptionMenuSettings.mLinespacing * 3 / 4 + 1, 0xff454545);
						screen.Clear (box_x, box_y, box_x + 32, box_y + OptionMenuSettings.mLinespacing * 3 / 4, this.mCVar.GetInt() | 0xff000000);
					}

					if (!(item is "PortalOptionMenuItemColorPicker"))
					{
						let newitem = new("PortalOptionMenuItemColorPicker");

						String menu = "Portal" .. item.GetAction();

						newitem.Init(item.mLabel, "");
						newitem.mCVar = OptionMenuItemColorPicker(item).mCVar;

						current.mDesc.mItems[i] = newitem;
					}	
				}
				else if (item is "OptionMenuItemStaticText")
				{
					let this = OptionMenuItemStaticText(item);

					label = Stringtable.Localize(item.mLabel);

					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, OptionMenuSettings.mTitleColor);
				}
				else if (item is "OptionMenuFieldBase")
				{
					let this = OptionMenuFieldBase(item);

					label = Stringtable.Localize(item.mLabel);
					bool grayed = this.mGrayCheck && !this.mGrayCheck.GetInt();

					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor, grayed);

					if (item is "OptionMenuItemTextField")
					{
						// reposition the text so that the cursor is visible when in entering mode.
						String text = OptionMenuItemTextField(this).Represent();
						int tlen = OptionWidth(current, text, accentfont);

						if (text.RightIndexOf(Menu.OptionFont().GetCursor()) == text.Length() - 1)
						{
							if (Menu.MenuTime() % 40 < 20) { text.DeleteLastCharacter(); }
						}

						if (item is "os_SearchField")
						{
							DrawValue(current, text, accentfont.StringWidth(label) + 20, y, spacing, accentfont, OptionMenuSettings.mFontColorValue, grayed);
						}
						else
						{
							int newindent = screen.GetWidth() - tlen - 10;
							if (newindent < indent) indent = newindent;

							DrawValue(current, text, indent, y, spacing, accentfont, OptionMenuSettings.mFontColorValue, grayed);
						}
					}
					else
					{
						DrawValue(current, this.Represent(), indent, y, spacing, accentfont, OptionMenuSettings.mFontColorValue, grayed);
					}
				}
				else if (item is "OptionMenuItemCommand")
				{
					label = Stringtable.Localize(item.mLabel);

					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor);
				}
				else if (item is "OptionMenuItemSubmenu")
				{
					DrawItemText(current, i, x + indent, y, accentfont, 0.6, Screen.GetWidth() - 20 - indent);

					let this = OptionMenuItemSubmenu(item);

					label = Stringtable.Localize(item.mLabel);
					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor);

					if (!(item is "PortalOptionMenuItemSubmenu"))
					{
						let newitem = new("PortalOptionMenuItemSubmenu");

						String menu = item.GetAction();

						if (
							menu ~== "NewPlayerMenu" ||
							menu ~== "JoystickConfigMenu" ||
							menu ~== "GameplayOptions" ||
							menu ~== "DeathmatchOptions" ||
							menu ~== "CoopOptions" ||
							menu ~== "CompatibilityOptions" ||
							menu ~== "CompatActorMenu" ||
							menu ~== "CompatDehackedMenu" ||
							menu ~== "CompatMapMenu" ||
							menu ~== "CompatPhysicsMenu" ||
							menu ~== "CompatRenderMenu" ||
							menu ~== "CompatSoundMenu" ||
							menu ~== "GLTextureGLOptions" ||
							menu ~== "ReverbEdit" ||
							menu ~== "ReverbSelect" ||
							menu ~== "ReverbSave"
						)
						{
							menu = "Portal" .. menu;
						}

						newitem.Init(item.mLabel, menu, this.mParam, item.mCentered);

						current.mDesc.mItems[i] = newitem;
					}
				}
				else
				{
					label = Stringtable.Localize(item.mLabel);

					DrawOptionText(current, label, item.mCentered ? x + 20 : x, y, accentfont, isSelected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor);
				}

//				DrawOptionText(current, item.GetClassName(), x + 700, y, accentfont, color(45, 0, 0, 0), true, 0.7);

				if (isSelected && item.Selectable())
				{
					double alpha = sin(Menu.MenuTime() * 10) / 2 + 0.5;
					screen.DrawText(NewSmallFont, OptionMenuSettings.mFontColorSelection, x - 12, y + 2, "►", DTA_Alpha, alpha);
				}
			}

			y += OptionMenuSettings.mLinespacing;
		}

		current.CanScrollUp = (current.mDesc.mScrollPos > 0);
		current.CanScrollDown = (i < current.mDesc.mItems.Size());
		current.VisBottom = i - 1;

		if (current.CanScrollUp)
		{
			Menu.DrawOptionText(3, ytop, OptionMenuSettings.mFontColorSelection, "▲");
		}
		if (current.CanScrollDown)
		{
			Menu.DrawOptionText(3 , y - 8, OptionMenuSettings.mFontColorSelection, "▼");
		}
	}

	static void DrawValue(OptionMenu this, String text, int indent, int y, int spacing, Font accentfont, int color, bool grayed = false)
	{
		DrawOptionText(this, text, indent + spacing, y, accentfont, color, grayed);
	}

	static void DrawOptionText(OptionMenu this, String text, int x, int y, Font accentfont, int color, bool grayed = false, double alpha = 1.0)
	{
		String label = Stringtable.Localize(text);
		int overlay = grayed ? Color(128, 64, 64, 64) : 0;
		screen.DrawText(accentfont, color, x, y, text, DTA_Alpha, alpha, DTA_ColorOverlay, overlay);
	}

	static void DrawSlider(OptionMenu current, OptionMenuSliderBase this, int x, int y, int spacing, Font accentfont, double min, double max, double cur, int fracdigits, int indent)
	{
		x += spacing;

		String formater = String.format("%%.%df", fracdigits);	// The format function cannot do the '%.*f' syntax.
		String textbuf;
		double range;
		int maxlen = 0;
		int right = x + (12 * 16 + 4);
		int cy = y + 3;

		range = max - min;
		double ccur = clamp(cur, min, max) - min;

		if (fracdigits >= 0)
		{
			textbuf = String.format(formater, max);
			maxlen = Menu.OptionWidth(textbuf);
		}

		this.mSliderShort = right + maxlen > screen.GetWidth();

		if (!this.mSliderShort)
		{
			DrawElement(x, cy, "Slider_L", 0x454545);
			for (int s = 1; s < 11; s++) { DrawElement(x + s * 16, cy, "Slider_M", 0x454545); }
			DrawElement(x + 11 * 16, cy, "Slider_R", 0x454545);
			DrawElement(x + int((5 + ((ccur * 156) / range))), cy, "Slider_H", 0x37A2AD);
		}
		else
		{
			// On 320x200 we need a shorter slider
			DrawElement(x, cy, "Slider_L", 0x454545);
			for (int s = 1; s < 6; s++) { DrawElement(x + s * 16, cy, "Slider_M", 0x454545); }
			DrawElement(x + 6 * 16, cy, "Slider_R", 0x454545);
			DrawElement(x + int((5 + ((ccur * 76) / range))), cy, "Slider_H", 0x37A2AD);

			right -= 5 * 16;;
		}

		if (fracdigits >= 0 && right + maxlen <= screen.GetWidth())
		{
			textbuf = String.format(formater, cur);
			DrawOptionText(current, textbuf, right, y, accentfont, Font.CR_DARKGRAY);
		}
	}

	static void DrawElement(double x, double y, String pic, int clr = 0)
	{
		let tex = TexMan.CheckForTexture (pic, TexMan.Type_MiscPatch);

		if (tex.isValid())
		{
			screen.DrawTexture(tex, true, int(x), int(y), DTA_DestWidth, 16, DTA_DestHeight, 16);
			if (clr > 0) { screen.DrawTexture(tex, true, int(x), int(y), DTA_DestWidth, 16, DTA_DestHeight, 16, DTA_FillColor, clr, DTA_Alpha, 0.5); }
		}
	}

	static int OptionWidth(OptionMenu this, String s, Font accentfont)
	{
		return accentfont.StringWidth(s);
	}

	static void DrawItemText(OptionMenu this, int index, double x = -1, double y = -1, Font accentfont = "NewSmallFont", double alpha = 0.6, int breakWidth = 300)
	{
		if (index < 0) { return; }

		double fontheight = accentfont.GetHeight();

		if (x < 0) { x = 160; }
		if (y < 0) { y = Screen.GetHeight() - (this.mDesc.mItems.Size() + 1 - index) * OptionMenuSettings.mLinespacing; }

		let item = this.mDesc.mItems[index];

		String text = StringTable.Localize(item.mLabel);
		text.Replace(" ", "");

		String lookupbase = StringTable.Localize(this.mDesc.mTitle);
		lookupbase.Replace(" ", "");

		String lookup = lookupBase .. "_" .. text;
		text = StringTable.Localize("$" .. lookup);
		if (text == lookup) { return; }

		BrokenLines message = accentfont.BreakLines(text, breakWidth);

		int c = message.Count();

		y -= fontheight / 2;
		y += OptionMenuSettings.mLinespacing / 2;

		for (int i = 0; i < c; i++)
		{
			screen.DrawText (accentfont, OptionMenuSettings.mFontColor, x, y, message.StringAt(i), DTA_Alpha, alpha);
			y += fontheight;
		}
	}


}

class PortalOptionMenuItemSubmenu : OptionMenuItemSubmenu {}

class PortalOptionMenuItemColorPicker : OptionMenuItemColorPicker
{
	override bool Activate()
	{
		if (mCVar != null)
		{
			Menu.MenuSound("menu/choose");
			
			// This code is a bit complicated because it should allow subclassing the
			// colorpicker menu.
			// New color pickers must inherit from the internal one to work here.
			
			let desc = MenuDescriptor.GetDescriptor('PortalColorpickerMenu');
			if (desc != NULL && (desc.mClass == null || desc.mClass is "PortalColorPickerMenu"))
			{
				let odesc = OptionMenuDescriptor(desc);
				if (odesc != null)
				{
					let cls = desc.mClass;
					if (cls == null) cls = "PortalColorpickerMenu";
					let picker = ColorpickerMenu(new(cls));
					picker.Init(Menu.GetCurrentMenu(), mLabel, odesc, mCVar);
					picker.ActivateMenu();
					return true;
				}
			}
		}
		return false;
	}
}

class PortalNewPlayerMenu : NewPlayerMenu
{
	override void Init(Menu parent, OptionMenuDescriptor desc)
	{
		Super.Init(parent, desc);
	}

	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);
		mPlayerDisplay.Drawer(false);
		
		int x = screen.GetWidth()/(CleanXfac_1*2) + PLAYERDISPLAY_X + PLAYERDISPLAY_W/2;
		int y = PLAYERDISPLAY_Y + PLAYERDISPLAY_H + 5;
		String str = Stringtable.Localize("$PLYRMNU_PRESSSPACE");
		screen.DrawText (NewSmallFont, Font.CR_GOLD, x - NewSmallFont.StringWidth(str)/2, y, str, DTA_VirtualWidth, CleanWidth_1, DTA_VirtualHeight, CleanHeight_1, DTA_KeepRatio, true);
		str = Stringtable.Localize(mRotation ? "$PLYRMNU_SEEFRONT" : "$PLYRMNU_SEEBACK");
		y += NewSmallFont.GetHeight();
		screen.DrawText (NewSmallFont, Font.CR_GOLD,x - NewSmallFont.StringWidth(str)/2, y, str, DTA_VirtualWidth, CleanWidth_1, DTA_VirtualHeight, CleanHeight_1, DTA_KeepRatio, true);
	}
}

class PortalJoystickConfigMenu : JoystickConfigMenu
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);
	}
}

class PortalGameplayMenu : GameplayMenu
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);

		String s = String.Format("dmflags = %d\ndmflags2 = %d", dmflags, dmflags2);
		screen.DrawText (OptionFont(), OptionMenuSettings.mFontColorValue, 40, screen.GetHeight() - OptionFont().GetHeight() * 2.5, s);
	}
}

class PortalCompatibilityMenu : CompatibilityMenu
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);

		String s = String.Format("compatflags = %d\ncompatflags2 = %d", compatflags, compatflags2);
		screen.DrawText (OptionFont(), OptionMenuSettings.mFontColorValue, 40, screen.GetHeight() - OptionFont().GetHeight() * 2.5, s);
	}
}

class PortalGLTextureGLOptions : GLTextureGLOptions
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);
	}
}

class PortalReverbEdit : ReverbEdit
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);
	}
}

class PortalReverbSelect : ReverbSelect
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);
	}
}

class PortalReverbSave : ReverbSave
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);
	}
}

class PortalColorPickerMenu : ColorPickerMenu
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);

		if (mCVar == null) return;
		int y = (-mDesc.mPosition + BigFont.GetHeight() + mDesc.mItems.Size() * OptionMenuSettings.mLinespacing) * CleanYfac_1;
		int fh = OptionMenuSettings.mLinespacing * CleanYfac_1;
		int h = (screen.GetHeight() - y) / 16;
		int w = fh;
		int yy = y;

		if (h > fh) h = fh;
		else if (h < 4) return;	// no space to draw it.
		
		int indent = (screen.GetWidth() / 2);
		int p = 0;

		for(int i = 0; i < 16; i++)
		{
			int box_x, box_y;
			int x1;

			box_y = y - 2 * CleanYfac_1;
			box_x = indent - 16*w;
			for (x1 = 0; x1 < 16; ++x1)
			{
				screen.Clear (box_x, box_y, box_x + w, box_y + h, 0, p);
				if ((mDesc.mSelectedItem == mStartItem+7) && 
					(/*p == CurrColorIndex ||*/ (i == mGridPosY && x1 == mGridPosX)))
				{
					int r, g, b;
					Color col;
					double blinky;
					if (i == mGridPosY && x1 == mGridPosX)
					{
						r = 255; g = 128; b = 0;
					}
					else
					{
						r = 200; g = 200; b = 255;
					}
					// Make sure the cursors stand out against similar colors
					// by pulsing them.
					blinky = abs(sin(MSTime()/1000.0)) * 0.5 + 0.5;
					col = Color(255, int(r*blinky), int(g*blinky), int(b*blinky));

					screen.Clear (box_x, box_y, box_x + w, box_y + 1, col);
					screen.Clear (box_x, box_y + h-1, box_x + w, box_y + h, col);
					screen.Clear (box_x, box_y, box_x + 1, box_y + h, col);
					screen.Clear (box_x + w - 1, box_y, box_x + w, box_y + h, col);
				}
				box_x += w;
				p++;
			}
			y += h;
		}
		y = yy;
		color newColor = Color(255, int(mRed), int(mGreen), int(mBlue));
		color oldColor = mCVar.GetInt() | 0xFF000000;

		int x = screen.GetWidth()*2/3;

		screen.Clear (x, y, x + 48*CleanXfac_1, y + 48*CleanYfac_1, oldColor);
		screen.Clear (x + 48*CleanXfac_1, y, x + 48*2*CleanXfac_1, y + 48*CleanYfac_1, newColor);

		y += 49*CleanYfac_1;
		screen.DrawText (SmallFont, Font.CR_GRAY, x+(48-SmallFont.StringWidth("---->")/2)*CleanXfac_1, y, "---->", DTA_CleanNoMove_1, true);
	}
}


class PortalOS_Menu : OS_Menu
{
	override void Drawer()
	{
		PortalOptionMenu.Draw(OptionMenu(self), 20, 20);
	}
}