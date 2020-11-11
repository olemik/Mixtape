# Mixtape

### How to run the program

### Changes File Structure

```json
{
      "changes" : [  
      {	
            "action" : "add_playlist",
            "user" : "Test",
            "songs" : [
            {
                "artist": "Artist",
                "title": "Song 1"
            }
            ]
      }
	]
}
```

### Suggested Application Scaling

****Problem:****  Very large input files and/or very large changes files.  
Some ideas that can be used for scaling the processing:  
- Extract playlists from the input file and save each one into its own file. Each playlist is independent from others so it can be processed
on its own.
- Use CSV format for the changes file so there is no need to load the whole file into memory (which is the case for JSON format).
- Split changes file by playlist into multiple smaller files. All changes affecting specific playlist will reside in the same file.
- Use database for keeping changes and/or playlists, songs and user information.
- Scale the processing by using one driver machine and multiple worker machines. Driver will be responsible for reading changes file, distributing changes to the worker nodes and merging final result. Each worker machine will have a subset of the playlists and will only get changes affecting those (one machine can be dedicated to new playlist creation). Each worker node will have a copy of user and song datasets.
