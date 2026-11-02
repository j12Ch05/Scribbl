# Scribbl

Scribbl Week
    Write it, Schedule it, Done.

This project aims to be a service that allows users save personal or 
professional notes and tie them to there calendar with email based alerts
as well as plan schedules and projects all saved to a postgre database

Check TODO.md for feature goals

1. Are there at least two roles with different rights?
    a user may be owner to a workspace and in extension a note,
    additionally a user may be organizer of an event or a subscriber to an event

2. Are there three related resources, or three lists?
    we have Users, Workspaces, Notes, Events, WorkspaceTags, EventTags, UserSettings, ThemeType

3. Is there a rule the server must enforce (capacity, dates, ownership…)?
    User must be signed in to use scribbl, users must verify there email to receive alerts
