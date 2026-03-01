USE [DSAU.Website.Staging]
GO

DROP TABLE [dbo].[Page]
GO

CREATE TABLE [dbo].[Page](
	[ID] [int] NOT NULL,
	[Title] [nvarchar](255) NULL,
	[PageURL] [nvarchar](max) NULL,
	[Slug] [nvarchar](100) NULL,
	[Content] [nvarchar](max) NULL,
	[TemplateName] [nvarchar](255) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO