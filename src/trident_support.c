/*
 * Trident - Automated Node Performance Metrics Collection Tool
 *
 * trident_support.c - Determines arch of node and evaluates its
 * support by the trident metrics collection tool
 *
 * Copyright (C) 2018, Servesh Muralidharan, IT-DI-WLCG-UP, CERN
 * Contact: servesh.muralidharan@cern.ch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include <sys/types.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <err.h>
#include <perfmon/err.h>
#include <perfmon/pfmlib.h>

#define STRMAXLEN	1024

int32_t main( int32_t argc, char **argv )
{
	if( argc < 2 )
		errx( -1, "trident_support usage: ./trident_support event_counters_directory" );
	
	int32_t ret;
	int32_t i;
	int32_t detected_arch = -1;
	pfm_pmu_info_t pinfo;
	memset( &pinfo, 0, sizeof( pinfo ) );

	ret = pfm_initialize();
	if( ret != PFM_SUCCESS )
		errx( -1, "trident_support: Cannot initialize PFM library: %s", pfm_strerror( ret ) );

	char supported_arch[ STRMAXLEN ];
	char ext[ STRMAXLEN ];
	DIR *dir_itr;
  	struct dirent *current_dir;
	printf( "trident_support: Scanning with metrics from %s\n", argv[ 1 ] );
	dir_itr = opendir( argv[ 1 ] );
	if( dir_itr )
	{
    	while( ( current_dir = readdir( dir_itr ) ) != NULL ) 
		{
      		//printf( "%s\n", current_dir->d_name );
			if( sscanf( current_dir->d_name, "%[^.].%4s", supported_arch, ext ) )
			{
				if( strncmp( ext, "evts", STRMAXLEN ) == 0 )
				{
					//printf( "Arch: %s %s \n", supported_arch, ext );
					for( i = 0; i < PFM_PMU_MAX; i++ )
    				{
				        if( pfm_get_pmu_info( i, &pinfo ) == PFM_SUCCESS && pinfo.is_present )
				        {
							if( strncmp( pinfo.name, supported_arch, STRMAXLEN ) == 0 )
							{
								//printf("%d, %s, \"%s\"\n", i, pinfo.name, pinfo.desc);
								if( detected_arch == -1 )
									detected_arch = i;
								else
									warnx( "trident_support: Warning multiple architecture matches found!!!" );
							}
						}
					}
				}
			}
    	}
    	closedir( dir_itr );
  	}

	if( detected_arch > 0 )
	{
		pfm_get_pmu_info( detected_arch, &pinfo );
		printf( "trident_support: %s architecture is detected, use <%s.evts>\n", pinfo.desc, pinfo.name );
	}
	else
		errx( -1, "trident_support: No supported architectures found in the current system!!!" );

	return detected_arch;
}
