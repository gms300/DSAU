CREATE OR ALTER PROCEDURE [dbo].[sp_GeneratePageMediaTree]
    @AsText BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Html NVARCHAR(MAX) = '
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8" />
        <style>
            body { margin: 0; padding: 0; font-family: sans-serif; height: 100vh; display: flex; overflow: hidden; }
            
            /* Sidebar Styling */
            #sidebar { 
                width: 350px; background: #2c3e50; color: #ecf0f1; 
                height: 100vh; overflow-y: auto; border-right: 1px solid #1a252f; 
                flex-shrink: 0;
            }
            .sidebar-header { padding: 20px; background: #1a252f; text-align: center; }
            .sidebar-header h2 { margin: 0; font-size: 1.2em; color: #3498db; }

            /* Main Content Area */
            #content-area { flex-grow: 1; height: 100vh; background: #fff; display: flex; flex-direction: column; }
            #content-title {
                flex-shrink: 0; padding: 10px 16px; background: #ecf0f1; border-bottom: 1px solid #bdc3c7;
                font-weight: 600; font-size: 0.95em; color: #2c3e50;
            }
            #content-area iframe { flex-grow: 1; width: 100%; border: none; min-height: 0; }

            /* Tree UI Logic */
            .section-group { border-bottom: 1px solid #34495e; }
            .section-header { 
                background: #34495e; padding: 12px 15px; cursor: pointer; 
                font-weight: bold; display: block; font-size: 0.9em;
            }
            .section-header:hover { background: #3d566e; }

            .tree-item { border-bottom: 1px solid #3d566e; }
            .toggle { display: none; }
            .toggle-label { 
                cursor: pointer; display: block; padding: 10px 15px 10px 35px; 
                font-size: 0.85em; position: relative; color: #bdc3c7;
            }
            .toggle-label:hover { background: #3d566e; color: #fff; }
            
            /* CSS Triangles */
            .toggle-label::before { 
                content: ""; position: absolute; left: 15px; top: 14px;
                border-top: 4px solid transparent; border-bottom: 4px solid transparent;
                border-left: 6px solid #7f8c8d; transition: transform 0.2s; 
            }
            .toggle:checked + .toggle-label::before { transform: rotate(90deg); border-left-color: #3498db; }
            
            /* Nested Lists */
            .nested-list { display: none; margin: 0; padding: 5px 0 10px 45px; background: #1a252f; list-style: none; }
            .toggle:checked ~ .nested-list { display: block; }
            
            .media-item { padding: 5px 0; font-size: 0.8em; }
            
            /* Links */
            a { color: inherit; text-decoration: none; display: inline-block; width: 100%; }
            .meta { font-size: 0.8em; color: #7f8c8d; margin-left: 5px; }
        </style>
    </head>
    <body>
        <div id="sidebar">
            <div class="sidebar-header">
                <h2>WP Site Audit</h2>
            </div>

            <div class="section-group">
                <input type="checkbox" id="main-pages" class="toggle" checked="checked" />
                <label for="main-pages" class="section-header">Site Pages</label>
                <div class="nested-list" style="padding-left:0;">';

    -- GENERATE LINKED PAGES
    DECLARE @PageRows NVARCHAR(MAX) = (
        SELECT 
            CAST(
                '<div class="tree-item">' +
                    '<input type="checkbox" id="p' + CAST(ISNULL([ID], 0) AS VARCHAR) + '" class="toggle" />' +
                    '<label for="p' + CAST(ISNULL([ID], 0) AS VARCHAR) + '" class="toggle-label">' +
                        -- TARGET="PREVIEW" opens the link in the iframe
                        '<a href="' + REPLACE(ISNULL([PageURL], '#'), '&', '&amp;') + '" target="preview">' + 
                            REPLACE(ISNULL([Title], 'Untitled'), '&', '&amp;') + 
                            ' <span class="meta">(' + CAST((SELECT COUNT(*) FROM [MediaLink] WHERE [LinkID] = [P].[ID] AND [LinkType] = 'Page Reference') AS VARCHAR) + ')</span>' + 
                        '</a>' +
                    '</label>' +
                    '<ul class="nested-list">' +
                        ISNULL(
                            (SELECT CAST(
                                '<li class="media-item">' +
                                    '<a href="' + REPLACE(ISNULL([M].[MediaURL], '#'), '&', '&amp;') + '" target="preview">' + 
                                        REPLACE(ISNULL([M].[FullName], 'Untitled Media'), '&', '&amp;') + 
                                    '</a>' +
                                '</li>' 
                            AS NVARCHAR(MAX))
                            FROM [MediaLink] [ML]
                            JOIN [Media] [M] ON [ML].[MediaID] = [M].[ID]
                            WHERE [ML].[LinkID] = [P].[ID] AND [ML].[LinkType] = 'Page Reference'
                            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 
                            '<li class="media-item meta">No media</li>'
                        ) +
                    '</ul>' +
                '</div>' 
            AS NVARCHAR(MAX))
        FROM [Page] [P]
        ORDER BY [Title]
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)');

    SET @Html += ISNULL(@PageRows, '') + '</div></div>';

    -- SECTION 2: ORPHANED MEDIA
    SET @Html += '
            <div class="section-group">
                <input type="checkbox" id="main-orphans" class="toggle" />
                <label for="main-orphans" class="section-header">Unlinked Media</label>
                <ul class="nested-list" style="padding-left: 15px;">';

    DECLARE @OrphanRows NVARCHAR(MAX) = (
        SELECT CAST(
            '<li class="media-item">' +
                '<a href="' + REPLACE(ISNULL([M].[MediaURL], '#'), '&', '&amp;') + '" target="preview">' + 
                    REPLACE(ISNULL([M].[FullName], 'Untitled Media'), '&', '&amp;') + 
                '</a>' +
            '</li>' 
        AS NVARCHAR(MAX))
        FROM [Media] [M]
        LEFT JOIN [MediaLink] [ML] ON [M].[ID] = [ML].[MediaID]
        WHERE [ML].[MediaID] IS NULL
        ORDER BY [M].[FullName]
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)');

    SET @Html += ISNULL(@OrphanRows, '<li class="media-item">No orphans</li>') + '</ul></div></div>';

    -- 3. THE CONTENT IFRAME AND TITLE
    SET @Html += '
        <div id="content-area">
            <div id="content-title">Select a page or media</div>
            <iframe name="preview" src="about:blank"></iframe>
        </div>
        <script>
            document.getElementById("sidebar").addEventListener("click", function(e) {
                var a = e.target.closest("a[target=\"preview\"]");
                if (!a) return;
                document.getElementById("content-title").textContent = a.textContent.trim();
                var isImg = /\.(png|jpe?g|gif|webp|svg)(\?|$)/i.test(a.href);
                if (isImg) {
                    e.preventDefault();
                    var url = a.href.replace(/&/g, "&amp;").replace(/"/g, "&quot;");
                    var html = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><style>html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;display:flex;align-items:center;justify-content:center;background:#333}img{max-width:100%;max-height:100%;object-fit:contain}</style></head><body><img src=\"" + url + "\" alt=\"\"></body></html>";
                    document.querySelector("iframe[name=\"preview\"]").src = "data:text/html;charset=utf-8," + encodeURIComponent(html);
                }
            });
        </script>
    </body>
    </html>';

    IF @AsText = 1
        SELECT @Html AS [RawHtmlOutput];
    ELSE
        SELECT CONVERT(XML, @Html, 2) AS [GeneratedAuditReport];
END