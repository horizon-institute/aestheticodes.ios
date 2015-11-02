/*
 * Aestheticodes recognises a different marker scheme that allows the
 * creation of aesthetically pleasing, even beautiful, codes.
 * Copyright (C) 2013-2015  The University of Nottingham
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU Affero General Public License as published
 *     by the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU Affero General Public License for more details.
 *
 *     You should have received a copy of the GNU Affero General Public License
 *     along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#import "JSONModel.h"
#import <Foundation/Foundation.h>

@protocol Marker
@end

@interface NSDictionary (Primitive)
-(BOOL)boolForKey:(NSString*)key withDefault:(bool)value;
@end

@interface Marker : JSONModel
@property (nonatomic, retain) NSString* code;
@property (nonatomic, retain) NSString* title;
@property (nonatomic, retain) NSString* description;
@property (nonatomic, retain) NSString* action;
@property (nonatomic, retain) NSString* image;
@property (nonatomic) bool showDetail;
@property (nonatomic) bool resetHistoryOnOpen;
@property (nonatomic, retain) NSString* changeToExperienceWithIdOnOpen;

-(void)load:(NSDictionary*) data;
-(NSDictionary*)toDictionary;

@end