//
//  AlbumCollectionCell.swift
//  Traveler
//
//  Created by Stephen Martinez on 5/22/17.
//  Copyright © 2017 Stephen Martinez. All rights reserved.
//

import UIKit

class AlbumCollectionCell: UICollectionViewCell{
    
    @IBOutlet weak var cellThumbnail: UIImageView!
    @IBOutlet weak var whiteSpinner: UIActivityIndicatorView!
    
    //Clears out the photo when downloading asyncronously from the Web.
    override func prepareForReuse() {super.prepareForReuse()
        cellThumbnail.image = TravelerCnst.clearPlaceholder
    }
    
}
