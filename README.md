# Mixtape

## How to run the program

### Prerequisite
Ruby interpreter is required for running this program. Ruby installation instructions can be found here: https://www.ruby-lang.org/en/documentation/installation/

```
./mixtape.rb -input <input file path> -output <output file path> -changes <changes file path> -threads <number of threads to use>
```

All arguments are optional, default values will be used instead.

## Changes File Structure

Mixtape changes are contained in a simple JSON file which can have three types of changes: add_playlist/remove_playlist/add_song:

```json
{
      "changes" : [  
      {	
            "action" : "add_playlist",
            "user" : "John",
            "songs" : [
            {
                "artist": "Artist",
                "title": "Song"
            }
            ]
      },
      {	
	    "action" : "remove_playlist",
	    "playlist_id": "1"
      },
      {	
	     "action" : "add_song",
	     "playlist_id": "2",
	     "artist": "Camila Cabello",
	     "title": "Havana"
      }
   ]
}
```
add_playlist/add_song changes can reference new or existing users and new or existing songs. New users and songs will be added to the final result and saved in output file.

## Ideas for Application Scaling

****Problem:****  Very large input files and/or very large changes files.  

Here are some ideas that can be used for scaling the processing:  
- Extract playlists from the input file and save each one into its own file. Each playlist is independent from others so it can be processed
on its own.
- Use CSV format for the changes file so there is no need to load the whole file into memory (which is the case for JSON format).
- Split changes file by playlist into multiple smaller files. All changes affecting specific playlist will reside in the same file and can be proccessed independently from others.
- Use database for keeping changes and/or playlists, songs and user information.
- Scale the processing by using one driver machine and multiple worker machines. Driver will be responsible for reading changes file, distributing changes to the worker nodes and merging the final result. Each worker machine will have a subset of the playlists to work on and will only get changes affecting those (one machine can be dedicated to new playlist creation). Each worker node will have a copy of user and song datasets, new users/songs will be created on a worker node and distributed to other machines.
