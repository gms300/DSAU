USE [DSAU.Website]
GO

ALTER TABLE [dbo].[MediaLink]  DROP CONSTRAINT [FK_MediaLink_Media] 
GO

DROP TABLE [dbo].[Media]
GO

CREATE TABLE [dbo].[Media](
	[ID] [int] NOT NULL,
	[Name] [nvarchar](255) NULL,
	[FullName] [nvarchar](2000) NULL,
	[Description] [nvarchar](max) NULL,
	[Slug] [nvarchar](2000) NULL,
	[MediaURL] [nvarchar](2000) NULL,
	[MimeType] [nvarchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[MediaLink]  WITH NOCHECK ADD  CONSTRAINT [FK_MediaLink_Media] FOREIGN KEY([MediaID])
REFERENCES [dbo].[Media] ([ID])
GO

ALTER TABLE [dbo].[MediaLink] CHECK CONSTRAINT [FK_MediaLink_Media]
GO