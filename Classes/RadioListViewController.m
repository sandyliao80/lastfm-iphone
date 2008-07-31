/* RadioListViewController.m - Display a Last.fm radio list
 * Copyright (C) 2008 Sam Steele
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#import "RadioListViewController.h"
#import "SearchViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"

@implementation RadioListViewController
- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super initWithCoder:decoder]) {
		_username = [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] retain];
	}
	return self;
}
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = username;
		_username = [username retain];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	int sections = 2;
	if(!_playlists) {
		_playlists = [[NSMutableArray alloc] init];
		NSArray *playlists = [[LastFMService sharedInstance] playlistsForUser:_username];
		for(NSDictionary *playlist in playlists) {
			if(![[playlist objectForKey:@"streamable"] isEqualToString:@"0"])
				[_playlists addObject:playlist];
		}
	}
	if([_playlists count]) sections++;
	[_recent release];
	_recent = [[[LastFMRadio sharedInstance] recentURLs] retain];
	if([_recent count]) sections++;
	return sections;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch(section) {
		case 0:
			return 1;
		case 1:
			return 4;
		case 2:
			return [_recent count]+1;
		case 3:
			return [_playlists count]+1;
	}
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([indexPath section] == 0 || [indexPath row] > 0)
		return 46;
	else
		return 24;
}
-(void)playRadioStation:(NSString *)url {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:url animated:YES];
	}
}
-(void)_rowSelected:(NSTimer *)timer {
	NSIndexPath *newIndexPath = (NSIndexPath *)[timer userInfo];
	
	if([newIndexPath section] > 0 && [newIndexPath row] == 0)
		return;
	
	switch([newIndexPath section]) {
		case 0:
		{
			SearchViewController *controller = [[SearchViewController alloc] initWithNibName:@"SearchView" bundle:nil];
			[self.navigationController pushViewController:controller animated:YES];
			break;
		}
		case 1:
			switch([newIndexPath row]-1) {
				case 0:
					[self performSelectorOnMainThread:@selector(playRadioStation:) withObject:[NSString stringWithFormat:@"lastfm://user/%@/personal", _username] waitUntilDone:YES];
					break;
				case 1:
					[self performSelectorOnMainThread:@selector(playRadioStation:) withObject:[NSString stringWithFormat:@"lastfm://user/%@/loved", _username] waitUntilDone:YES];
					break;
				case 2:
					[self performSelectorOnMainThread:@selector(playRadioStation:) withObject:[NSString stringWithFormat:@"lastfm://user/%@/recommended", _username] waitUntilDone:YES];
					break;
			}
		case 2:
			[self performSelectorOnMainThread:@selector(playRadioStation:) withObject:[[_recent objectAtIndex:[newIndexPath row]-1] objectForKey:@"url"] waitUntilDone:YES];
			break;
		case 3:
			[self performSelectorOnMainThread:@selector(playRadioStation:) withObject:[NSString stringWithFormat:@"lastfm://playlist/%@/shuffle", [[_playlists objectAtIndex:[newIndexPath row]-1] objectForKey:@"id"]] waitUntilDone:YES];
			break;
	}
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	if([newIndexPath row] > 0) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_rowSelected:)
																 userInfo:newIndexPath
																	repeats:NO];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
	UIImageView *v;
	UILabel *l;

	switch([indexPath section]) {
		case 0:
			v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_button.png"]];
			cell.backgroundView = v;
			[v release];
			l = [[UILabel alloc] initWithFrame:CGRectMake(10,0,280,46)];
			l.textAlignment = UITextAlignmentLeft;
			l.font = [UIFont boldSystemFontOfSize:18];
			l.textColor = [UIColor whiteColor];
			l.shadowColor = [UIColor grayColor];
			l.shadowOffset = CGSizeMake(-1,-1);
			l.backgroundColor = [UIColor clearColor];
			l.text = @"Start a New Station";
			[cell.contentView addSubview:l];
			[l release];
			break;
		case 1:
			switch([indexPath row]) {
				case 0:
					v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
					cell.backgroundView = v;
					l = [[UILabel alloc] initWithFrame:v.frame];
					l.textAlignment = UITextAlignmentCenter;
					l.font = [UIFont boldSystemFontOfSize:14];
					l.textColor = [UIColor whiteColor];
					l.shadowColor = [UIColor blackColor];
					l.shadowOffset = CGSizeMake(-1,0);
					l.backgroundColor = [UIColor clearColor];
					l.text = @"My Stations";
					[cell.contentView addSubview:l];
					[l release];
					[v release];
					break;
				case 1:
					cell.text = @"My Library";
					break;
				case 2:
					cell.text = @"Loved Tracks";
					break;
				case 3:
					cell.text = @"Recommended by Last.fm";
					break;
			}
			break;
		case 2:
			if([indexPath row] == 0) {
				v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
				cell.backgroundView = v;
				l = [[UILabel alloc] initWithFrame:v.frame];
				l.textAlignment = UITextAlignmentCenter;
				l.font = [UIFont boldSystemFontOfSize:14];
				l.textColor = [UIColor whiteColor];
				l.shadowColor = [UIColor blackColor];
				l.shadowOffset = CGSizeMake(-1,0);
				l.backgroundColor = [UIColor clearColor];
				l.text = @"Recent Stations";
				[cell.contentView addSubview:l];
				[l release];
				[v release];
			} else {
				cell.text = [[_recent objectAtIndex:[indexPath row]-1] objectForKey:@"name"];
			}
			break;
		case 3:
			if([indexPath row] == 0) {
				v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
				cell.backgroundView = v;
				l = [[UILabel alloc] initWithFrame:v.frame];
				l.textAlignment = UITextAlignmentCenter;
				l.font = [UIFont boldSystemFontOfSize:14];
				l.textColor = [UIColor whiteColor];
				l.shadowColor = [UIColor blackColor];
				l.shadowOffset = CGSizeMake(-1,0);
				l.backgroundColor = [UIColor clearColor];
				l.text = @"My Playlists";
				[cell.contentView addSubview:l];
				[l release];
				[v release];
			} else {
				cell.text = [[_playlists objectAtIndex:[indexPath row]-1] objectForKey:@"title"];
			}
			break;
	}
	[cell showProgress: NO];
	if([indexPath row] > 0) {
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		img.opaque = YES;
		cell.accessoryView = img;
		[img release];
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_loadingThread cancel];
	[_username release];
	[_playlists release];
	[_recent release];
}
@end