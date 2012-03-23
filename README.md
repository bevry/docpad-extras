# docpad-images

docpad plugin to provide access to an array of paths to images associated with the current document during document rendering

## Install

Put images.plugin.coffee into /plugins/images/. Change pathnames in images.plugin.coffee if you need to and comment out automatic folder creation if you don't want that.

## Usage

docpad-images uses folders named according to the <code>basename</code> (filename minus extension) property of each document.

Running <code>docpad generate</code> with docpad-images installed will automatically create a set of folders in <code>/src/public/images/</code>. Images in <code>/src/public/images/[basename]</code> will subsequently be accesible to the document with the basename <code>[basename]</code> during document rendering (i.e. in a template or in a plugin that is triggered after the initial <code>render</code> pass).

(If you don't want folder automatically created for every document, you can comment it out in the plugin and create them manually. If you want to use different path-names, you must also modify the plugin directly.)

In a template (example in Coffeekup):

~~~
body ->
	div class: 'example', ->
		for image in @document.images
			img src: document.url, -> document.title
~~~

Renders to:

~~~
<body>
	<div class="example">
		<img src="/images/img1.jpg"><img src="/images/img2.jpg">< ... etc.
	</div>
</body>
~~~
