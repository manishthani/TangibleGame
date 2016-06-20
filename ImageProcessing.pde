import java.util.Random;
import processing.video.*;

class ImageProcessing extends PApplet {

  PImage img, temp, result;
  public Movie cam;
  ArrayList<PVector> intersect, lines;
  TwoDThreeD t;
  boolean pres, quadFound;


  void settings() {
    size(640, 480);
  }

  void setup() {
    pres = false;
    /***** For static image *****/
    /*img = loadImage("/Users/manishthani/Desktop/TangibleGame/data/board1.jpg");
    temp = createImage(img.width, img.height, RGB);
    result = createImage(img.width, img.height, RGB);*/

    /***** For camera *****/
    //cam = new Capture (this, camra[63]);
    //cam.start();

    /***** For video *****/
    cam = new Movie(this, "/Users/manishthani/Desktop/TangibleGame/data/testvideo.mp4");
    cam.loop();
 
    if (cam.available()) {
      cam.read();
    } 
    img = cam.get();

    temp = createImage(cam.width, cam.height, RGB);
    result = createImage(cam.width, cam.height, RGB);
  }

  void draw() {
    cam.loadPixels();
    if (cam.available()) {
      cam.read();
    } 
    img = cam.get();
    cam.updatePixels();
    
    image (img, 0, 0);

    thresholding(img); // save in temp
    blur(temp); // save in result
    sobel(result);
    t = new TwoDThreeD(800, 600);
    lines = hough(temp);
    boolean goOn = false;
    if (lines.size() > 3) {
      goOn = true;
      intersect = getIntersections(lines);
      
      // Filtering intersections out of image
      for(int i = 0; i < intersect.size(); ++i){
        if (intersect.get(i).x > img.width || intersect.get(i).y > img.height){
          intersect.remove(i);
        }
      } 
      if (intersect.size() < 3) goOn = false;
    }


    if (goOn) {
      // Selection of quads
      QuadGraph graph = new QuadGraph();
      graph.build(lines, width, height);
      List<int[]> quads = graph.findCycles();
    
      if (quads.size() > 0) {
        quadFound = false;
        ArrayList<PVector> newIntersections = new ArrayList<PVector> ();
        for (int[] quad : quads) {
          List<PVector> quadSorted = new ArrayList<PVector>();
          quadSorted.add(intersect.get(quad[0]));
          quadSorted.add(intersect.get(quad[1]));
          quadSorted.add(intersect.get(quad[2]));
          quadSorted.add(intersect.get(quad[3]));

          quadSorted = graph.sortCorners(quadSorted);

          PVector num1 = quadSorted.get(0);
          PVector num2 = quadSorted.get(1);
          PVector num3 = quadSorted.get(2);
          PVector num4 = quadSorted.get(3);

          if (graph.isConvex(num1, num2, num3, num4) && graph.nonFlatQuad(num1, num2, num3, num4) && graph.validArea(num1, num2, num3, num4, width*height, (width*height)/5)) {
            newIntersections.clear();
            newIntersections.add(num1);
            newIntersections.add(num2);
            newIntersections.add(num3);
            newIntersections.add(num4);
        
            //fill(255,0,0);
            //quad(num1.x, num1.y, num2.x, num2.y, num3.x, num3.y, num4.x, num4.y);
            quadFound = true;
          }
        }
        if(newIntersections.size() > 0) intersect = newIntersections;
        else intersect.clear();
      }
    }
  }


  List<PVector> sortCorners(List<PVector> quad) {
    // Sort corners so that they are ordered clockwise
    PVector a = quad.get(0);
    PVector b = quad.get(2);
    PVector center = new PVector((a.x+b.x)/2, (a.y+b.y)/2);
    java.util.Collections.sort(quad, new CWComparator(center));

    a = quad.get(0);
    b = quad.get(2);
    center = new PVector((a.x+b.x)/2, (a.y+b.y)/2);
    // TODO:
    // Re-order the corners so that the first one is the closest to the
    // origin (0,0) of the image.
    float mag = width * height;
    int pos = 0;
    for ( int i = 0; i < quad.size(); ++i) {
      if (quad.get(i).mag() < mag) {
        pos = i;
        mag = quad.get(i).mag();
      }
    }
    // You can use Collections.rotate to shift the corners inside the quad.
    Collections.rotate(quad, -pos);
    return quad;
  }

  PVector getRotation() {
    if (!quadFound || intersect.size() != 4) {
      return new PVector (0, 0, 0);
    }
    return t.get3DRotations(sortCorners(intersect));
  }

  PImage getVideo() {
    if (cam != null && cam.available()) {
      return cam.copy();
    } else return createImage(width, height, RGB);
  }



  // Gaussian blur
  void blur (PImage img) {
    imgproc.result.loadPixels();
    float[][] kernel = { { 9, 12, 9 }, 
      {12, 15, 12 }, 
      { 9, 12, 9 }};

    float [][] temp =  {{ 0, 0, 0 }, 
      { 0, 0, 0 }, 
      { 0, 0, 0 }};

    float count, N = 3;
    float weight = 120.f;

    for (int i = img.width; i < img.width * img.height - img.width; i++) {

      if ((i % img.width != 0) && (i % img.width != img.width-1)) {
        count = 0;

        temp[0][0] = imgproc.brightness(img.pixels[i -img.width -1]) * kernel [0][0]; 
        temp[0][1] = imgproc.brightness(img.pixels[i -img.width]) * kernel [0][1];
        temp[0][2] = imgproc.brightness(img.pixels[i -img.width +1]) * kernel [0][2];
        temp[1][0] = imgproc.brightness(img.pixels[i - 1]) * kernel [1][0];
        temp[1][1] = imgproc.brightness(img.pixels[i]) * kernel [1][1];
        temp[1][2] = imgproc.brightness(img.pixels[i + 1]) * kernel [1][2];
        temp[2][0] = imgproc.brightness(img.pixels[i + img.width -1]) * kernel [2][0];
        temp[2][1] = imgproc.brightness(img.pixels[i + img.width]) * kernel [2][1];
        temp[2][2] = imgproc.brightness(img.pixels[i + img.width +1]) * kernel [2][2];

        for (int j = 0; j < N; j++) {
          for (int k = 0; k < N; k++) {
            count = count + temp[j][k];
          }
        }
        float c = color(count / weight);
        int col = getIntFromColor(c, c, c);
        imgproc.result.pixels[i] = col;
      }
    }
    imgproc.result.updatePixels();
  }


  int getIntFromColor(float Red, float Green, float Blue) {
    int R = Math.round(255 * Red);
    int G = Math.round(255 * Green);
    int B = Math.round(255 * Blue);

    R = (R << 16) & 0x00FF0000;
    G = (G << 8) & 0x0000FF00;
    B = B & 0x000000FF;

    return 0xFF000000 | R | G | B;
  }
}