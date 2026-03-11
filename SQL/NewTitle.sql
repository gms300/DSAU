CREATE TABLE [NewMediaTitle]
(
    [MediaID] INT NOT NULL PRIMARY KEY,
    [MediaFullName] NVARCHAR(100) NOT NULL,
    [OldTitle] NVARCHAR(100) NOT NULL,
    [PageSlug] NVARCHAR(100) NOT NULL,
    [NewTitle] NVARCHAR(100) NOT NULL
);

DELETE FROM [NewMediaTitle]

INSERT INTO [NewMediaTitle] ([MediaID], [MediaFullName], [OldTitle], [PageSlug], [NewTitle])

select [t].[ID] AS [MediaID], [t].[FullName], [t].[Name], [p].[Slug] [PageSlug],
       CONCAT([p].[Slug], '_', FORMAT(ROW_NUMBER() OVER (PARTITION BY [p].[Slug] ORDER BY [t].[ID]), '000')) AS [NewTitle]
from 
(
select *
, (select count(1) from [MediaLink] [ml] where [ml].[MediaID] = [m].[ID]) [LinkCount]
from   [Media] [m]
) [t]

join [MediaLink] [ml] on [ml].[MediaID] = [t].[ID]
join [Page] [p] on [p].[ID] = [ml].[LinkID]

where [t].[LinkCount] = 1


select * from [NewMediaTitle]
order by NewTitle